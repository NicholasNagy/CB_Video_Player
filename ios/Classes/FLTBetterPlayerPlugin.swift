import Flutter
import AVFoundation
import GLKit
import KTVHTTPCache
import MediaPlayer
import AVKit

// Helper functions

// This function converts a CMTime object 
// (used in AVFoundation to represent time values) into an 
// integer value representing milliseconds (Int64).
func FLTCMTimeToMillis(_ time: CMTime) -> Int64 {
    if time.timescale == 0 { return 0 }
    return Int64(time.value * 1000 / Int64(time.timescale))
}

// This function converts a TimeInterval 
// (a Double representing time in seconds) into an integer value 
// representing milliseconds (Int64).
func FLTNSTimeIntervalToMillis(_ interval: TimeInterval) -> Int64 {
    return Int64(interval * 1000.0)
}


// FLTFrameUpdater
// This class is a helper class designed to manage frame updates for a video texture in a Flutter application. 
// It works in conjunction with the FlutterTextureRegistry to notify Flutter when a new video frame is available for rendering.
class FLTFrameUpdater: NSObject {
    // An identifier (Int64) for the texture associated with the video. This ID is used to notify Flutter about frame updates for the specific texture.
    var textureId: Int64 = 0

    // A weak reference to the FlutterTextureRegistry, which is responsible for managing textures in the Flutter engine.
    weak var registry: FlutterTextureRegistry?
    
    // This method initializes the FLTFrameUpdater with a reference to the FlutterTextureRegistry. 
    // This allows the class to notify Flutter when a new frame is available.
    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
    }
    
    // This method is called periodically by a CADisplayLink, which is a timer that synchronizes with the display's refresh rate (e.g., 60Hz).
    @objc func onDisplayLink(_ link: CADisplayLink) {
        // The textureFrameAvailable function of the FlutterTextureRegistry is called with the textureId. 
        // This notifies Flutter that a new frame is available for the texture, prompting Flutter to render the updated frame.
        registry?.textureFrameAvailable(textureId)
    }
}

// KVO Context Pointers
// These pointers are used for Key-Value Observing to monitor changes in the player's properties
private var rateContext = 0
private var timeRangeContext = 0
private var statusContext = 0
private var playbackLikelyToKeepUpContext = 0
private var playbackBufferEmptyContext = 0
private var playbackBufferFullContext = 0
private var presentationSizeContext = 0


// FLTBetterPlayer
// This class implements the core video player functionality and interfaces with Flutter
class FLTBetterPlayer: NSObject, FlutterTexture, FlutterStreamHandler {
    // Properties
    private(set) var player: AVPlayer                      // The AVPlayer instance that handles media playback
    private(set) var videoOutput: AVPlayerItemVideoOutput? // Outputs video frames for rendering
    private(set) var displayLink: CADisplayLink            // Synchronizes frame updates with the display refresh rate
    var eventChannel: FlutterEventChannel?                 // Channel for sending events to Flutter
    var eventSink: FlutterEventSink?                       // Sink for sending events through the eventChannel
    var preferredTransform: CGAffineTransform = .identity  // Transform for adjusting video orientation
    private(set) var disposed: Bool = false                // Flag indicating if the player has been disposed
    private(set) var isPlaying: Bool = false               // Flag indicating if video is currently playing
    var isSeeking: Bool = false                            // Flag indicating if seeking operation is in progress
    var isLooping: Bool = false                            // Flag indicating if video should loop
    private(set) var isInitialized: Bool = false           // Flag indicating if player is initialized
    private(set) var key: String?                          // Unique identifier for the video
    private(set) var prevBuffer: CVPixelBuffer?            // Previous video frame buffer
    private(set) var failedCount: Int = 0                  // Counter for tracking frame retrieval failures
    var _playerLayer: AVPlayerLayer?                       // Layer for rendering video when not using texture
    var _observersAdded: Bool = false                      // Flag indicating if KVO observers have been added
    var stalledCount: Int = 0                              // Counter for tracking stall events
    var playerRate: Float = 1.0                            // Playback speed rate
    weak var frameUpdater: FLTFrameUpdater?                // Reference to the frame updater
    
    // Initialization
    init(frameUpdater: FLTFrameUpdater) {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .none
        isInitialized = false
        isPlaying = false
        disposed = false
        isSeeking = false
        self.frameUpdater = frameUpdater
        
        // Create display link to synchronize with screen refresh rate
        self.displayLink = CADisplayLink(target: frameUpdater, selector: #selector(FLTFrameUpdater.onDisplayLink))
        
        super.init()
        
        // Fix for loading large videos - prevents automatic stalling for buffering
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        
        // Add the display link to the current run loop
        displayLink.add(to: RunLoop.current, forMode: .common)
        displayLink.isPaused = true
        _observersAdded = false
    }

    // Returns the texture identifier assigned to this player
    func textureId() -> Int64 {
        return frameUpdater?.textureId ?? 0
    }

    // Observer Management
    // Adds Key-Value Observers to monitor player and item state changes
    func addObservers(to item: AVPlayerItem) {
        if !_observersAdded {
            // Add observers for player and item properties to track state changes
            player.addObserver(self, forKeyPath: "rate", options: [], context: &rateContext)
            item.addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &timeRangeContext)
            item.addObserver(self, forKeyPath: "status", options: [], context: &statusContext)
            item.addObserver(self, forKeyPath: "presentationSize", options: [], context: &presentationSizeContext)
            item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [], context: &playbackLikelyToKeepUpContext)
            item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [], context: &playbackBufferEmptyContext)
            item.addObserver(self, forKeyPath: "playbackBufferFull", options: [], context: &playbackBufferFullContext)
            
            // Add notification observer for when the video finishes playing
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(itemDidPlayToEndTime),
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
            _observersAdded = true
        }
    }

    // Removes the video output from the current item
    func removeVideoOutput() {
        videoOutput = nil
        guard let currentItem = player.currentItem else { return }
        
        // Remove all outputs from the current item
        for output in currentItem.outputs {
            currentItem.remove(output)
        }
    }

    // Resets the player state and cleans up resources
    func clear() {
        displayLink.isPaused = true
        isInitialized = false
        isPlaying = false
        disposed = false
        videoOutput = nil
        failedCount = 0
        key = nil
        
        guard let currentItem = player.currentItem else { return }
        
        removeObservers()
        currentItem.asset.cancelLoading()
    }

    // Removes all observers to prevent memory leaks
    func removeObservers() {
        if _observersAdded {
            // Remove all KVO observers
            player.removeObserver(self, forKeyPath: "rate", context: &rateContext)
            
            if let currentItem = player.currentItem {
                currentItem.removeObserver(self, forKeyPath: "status", context: &statusContext)
                currentItem.removeObserver(self, forKeyPath: "presentationSize", context: &presentationSizeContext)
                currentItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &timeRangeContext)
                currentItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: &playbackLikelyToKeepUpContext)
                currentItem.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: &playbackBufferEmptyContext)
                currentItem.removeObserver(self, forKeyPath: "playbackBufferFull", context: &playbackBufferFullContext)
            }
            
            NotificationCenter.default.removeObserver(self)
            _observersAdded = false
        }
    }

    // Playback Control
    // Handles end of playback - either loops or sends completion event
    @objc func itemDidPlayToEndTime(_ notification: Notification) {
        if isLooping {
            // To prevent reloading the entire video again, we seek to 1ms
            // This happens because the first millisecond isn't buffered at the start
            // so when we seek to 0, it will buffer as if nothing was previously buffered
            seekTo(1)
        } else {
            if let eventSink = eventSink, let key = key {
                // Notify Flutter that playback has completed
                eventSink(["event": "completed", "key": key])
                removeObservers()
            }
            player.pause()
            isPlaying = false
            displayLink.isPaused = true
        }
    }

    // Helper function to convert radians to degrees
    fileprivate func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        let degrees = GLKMathRadiansToDegrees(Float(radians))
        if degrees < 0 {
            return CGFloat(degrees) + 360
        }
        // Output degrees in between [0, 360)
        return CGFloat(degrees)
    }

    // Video Composition
    // Creates a video composition to handle video orientation/transformation
    func getVideoComposition(withTransform transform: CGAffineTransform,
                        withAsset asset: AVAsset,
                        withVideoTrack videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        // Create composition instruction for the full video duration
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        // Create layer instruction with the preferred transform
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        
        // Create and configure the video composition
        let videoComposition = AVMutableVideoComposition()
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // If in portrait mode, switch the width and height of the video
        var width = videoTrack.naturalSize.width
        var height = videoTrack.naturalSize.height
        let rotationDegrees =
            Int(round(radiansToDegrees(atan2(preferredTransform.b, preferredTransform.a))))
        
        if rotationDegrees == 90 || rotationDegrees == 270 {
            width = videoTrack.naturalSize.height
            height = videoTrack.naturalSize.width
        }
        videoComposition.renderSize = CGSize(width: width, height: height)
        
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        return videoComposition
    }

    // Video Output Configuration
    // Adds a video output to the current player item for frame retrieval
    func addVideoOutput() {
        guard let currentItem = player.currentItem else {
            return
        }
        
        // Check if video output is already added to avoid duplication
        if let videoOutput = videoOutput {
            let outputs = currentItem.outputs
            for output in outputs {
                if output === videoOutput {
                    return
                }
            }
        }
        
        // Configure pixel buffer attributes for the video output
        let pixBuffAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        // Create and add the video output to the player item
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributes)
        if let videoOutput = videoOutput {
            currentItem.add(videoOutput)
        }
    }

    // Fixes the transform for video orientation based on track metadata
    func fixTransform(_ videoTrack: AVAssetTrack) -> CGAffineTransform {
        var transform = videoTrack.preferredTransform
        if transform.tx == 0 && transform.ty == 0 {
            let rotationDegrees = Int(round(radiansToDegrees(atan2(transform.b, transform.a))))
            NSLog("TX and TY are 0. Rotation: %d. Natural width,height: %f, %f", rotationDegrees,
                videoTrack.naturalSize.width, videoTrack.naturalSize.height)
            
            // Fix transform for different rotation angles
            if rotationDegrees == 90 {
                NSLog("Setting transform tx")
                transform.tx = videoTrack.naturalSize.height
                transform.ty = 0
            } else if rotationDegrees == 270 {
                NSLog("Setting transform ty")
                transform.tx = 0
                transform.ty = videoTrack.naturalSize.width
            }
        }
        return transform
    }

    // Data Source Setup
    // Sets up a local asset file as the data source
    func setDataSourceAsset(_ asset: String, withKey key: String, overriddenDuration: Int) {
        let path = Bundle.main.path(forResource: asset, ofType: nil)
        if let path = path {
            let url = URL(fileURLWithPath: path)
            setDataSourceURL(url, withKey: key, withHeaders: [:], withCache: false, overriddenDuration: overriddenDuration)
        }
    }

    // Sets up a URL as the data source, handling caching and custom headers
    func setDataSourceURL(_ url: URL, withKey key: String, withHeaders headers: [String: String], withCache useCache: Bool, overriddenDuration: Int) {
        var headersDictionary = headers
        if headers is NSNull {
            headersDictionary = [:]
        }
        
        let item: AVPlayerItem
        
        if useCache {
            // Use KTVHTTPCache for caching if enabled
            KTVHTTPCache.downloadSetAdditionalHeaders(headersDictionary)
            if let proxyURL = KTVHTTPCache.proxyURL(withOriginalURL: url) {
                item = AVPlayerItem(url: proxyURL)
            } else {
                item = AVPlayerItem(url: url) // Fallback to the original URL if proxyURL is nil
            }
        } else {
            // Convert headers dictionary to [String: String] format
            let stringHeaders = headersDictionary.reduce(into: [String: String]()) { result, element in
                if let stringValue = element.value as? String {
                    result[element.key] = stringValue
                }
            }
            
            // Create asset with custom HTTP headers
            let asset = AVURLAsset(
                url: url, 
                options: ["AVURLAssetHTTPHeaderFieldsKey": stringHeaders]
            )
            item = AVPlayerItem(asset: asset)
            if #available(iOS 10.0, *) {
                let k = 3.0
                item.preferredForwardBufferDuration = k
            }
        }
        
        // Set custom duration if provided (iOS 10+ only)
        if #available(iOS 10.0, *), overriddenDuration > 0 {
            // Convert overriddenDuration from milliseconds to a proper CMTime
            item.forwardPlaybackEndTime = CMTimeMake(value: Int64(overriddenDuration), timescale: 1000)
        }
        
        setDataSourcePlayerItem(item, withKey: key)
    }

    // Sets up a player item as the data source and configures it
    func setDataSourcePlayerItem(_ item: AVPlayerItem, withKey key: String) {
        self.key = key
        stalledCount = 0
        playerRate = 1.0
        player.replaceCurrentItem(with: item)
        
        let asset = item.asset
        
        // Completion handler for asset loading
        let assetCompletionHandler: () -> Void = { [weak self] in
            guard let self = self else { return }
            
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if !tracks.isEmpty {
                    let videoTrack = tracks[0]
                    
                    // Completion handler for video track loading
                    let trackCompletionHandler: () -> Void = { [weak self] in
                        guard let self = self, !self.disposed else { return }
                        
                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            // Rotate the video by using a videoComposition and the preferredTransform
                            self.preferredTransform = self.fixTransform(videoTrack)
                            
                            // Use the asset's duration explicitly
                            let videoComposition = self.getVideoComposition(
                                withTransform: self.preferredTransform,
                                withAsset: asset,
                                withVideoTrack: videoTrack
                            )
                            item.videoComposition = videoComposition
                        }
                    }
                    
                    // Load video track properties asynchronously
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"], 
                        completionHandler: trackCompletionHandler)
                }
            }
        }
        
        // Load asset properties asynchronously
        asset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: assetCompletionHandler)
        addObservers(to: item)
    }

    // Stall Handling
    // Handles video playback stalls
    @objc func handleStalled() {
        if player.currentItem?.isPlaybackLikelyToKeepUp == true ||
        availableDuration() - CMTimeGetSeconds(player.currentItem?.currentTime() ?? .zero) > 10.0 {
            // If playback is likely to keep up or we have more than 10 seconds buffered,
            // we don't need to do anything special
        } else {
            stalledCount += 1
            if stalledCount > 50 {
                // Too many stalls, report error to Flutter
                eventSink?(FlutterError(
                    code: "VideoError",
                    message: "Failed to load video: playback stalled",
                    details: nil)
                )
                return
            }
            // Recursively check for stall again after 1 second
            perform(#selector(handleStalled), with: nil, afterDelay: 1.0)
        }
    }

    // Calculates available playback duration based on loaded time ranges
    func availableDuration() -> TimeInterval {
        guard let currentItem = player.currentItem,
            let loadedTimeRanges = currentItem.loadedTimeRanges as? [NSValue],
            loadedTimeRanges.count > 0 else {
            return 0
        }
        
        let timeRange = loadedTimeRanges[0].timeRangeValue
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        let result = startSeconds + durationSeconds
        
        return result
    }

    // KVO Observation
    // Handles all Key-Value Observation callbacks
    override func observeValue(forKeyPath path: String?,
                            of object: Any?,
                            change: [NSKeyValueChangeKey: Any]?,
                            context: UnsafeMutableRawPointer?) {
        guard let path = path else { return }

        if context == &rateContext {
            // Handle changes to playback rate (detect stalls)
            if player.rate == 0, // if player rate dropped to 0
            let currentTime = player.currentItem?.currentTime(),
            let duration = player.currentItem?.duration,
            currentTime > CMTime.zero, // video was started
            currentTime < duration, // but not yet finished
            isPlaying { // instance variable to handle overall state (changed to true when user triggers playback)
                handleStalled()
            }
        } else if context == &timeRangeContext {
            // Handle changes to loaded time ranges (buffering progress)
            guard let eventSink = eventSink, let key = key else { return }

            let values = NSMutableArray()
            if let object = object as? AVPlayerItem, let loadedTimeRanges = object.loadedTimeRanges as? [NSValue] {
                for rangeValue in loadedTimeRanges {
                    let range = rangeValue.timeRangeValue
                    let start = FLTCMTimeToMillis(range.start)
                    var end = start + FLTCMTimeToMillis(range.duration)

                    // Ensure we don't exceed any custom end time
                    if let forwardPlaybackEndTime = player.currentItem?.forwardPlaybackEndTime,
                    !CMTIME_IS_INVALID(forwardPlaybackEndTime) {
                        let endTime = FLTCMTimeToMillis(forwardPlaybackEndTime)
                        if end > endTime {
                            end = endTime
                        }
                    }

                    values.add([NSNumber(value: start), NSNumber(value: end)])
                }
            }
            // Send buffering update event to Flutter
            eventSink(["event": "bufferingUpdate", "values": values, "key": key])
        } else if context == &presentationSizeContext {
            // Video size is now known, try to initialize the player
            onReadyToPlay()
        } else if context == &statusContext {
            // Handle player item status changes
            guard let item = object as? AVPlayerItem else { return }

            switch item.status {
            case .failed:
                NSLog("Failed to load video:")
                NSLog("%@", item.error.map { String(describing: $0) } ?? "unknown error")

                if let eventSink = eventSink {
                    let message = "Failed to load video: " + (item.error?.localizedDescription ?? "")
                    eventSink(FlutterError(code: "VideoError", message: message, details: nil))
                }
            case .unknown:
                // Still loading, nothing to do yet
                break
            case .readyToPlay:
                // Item is ready to play, initialize the player
                onReadyToPlay()
            @unknown default:
                break
            }
        } else if context == &playbackLikelyToKeepUpContext {
            // Handle playback likely to keep up changes (buffering state)
            if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                updatePlayingState()
                if let eventSink = eventSink, let key = key {
                    eventSink(["event": "bufferingEnd", "key": key])
                }
            }
        } else if context == &playbackBufferEmptyContext {
            // Handle buffer empty state (start buffering)
            if let eventSink = eventSink, let key = key {
                eventSink(["event": "bufferingStart", "key": key])
            }
        } else if context == &playbackBufferFullContext {
            // Handle buffer full state (end buffering)
            if let eventSink = eventSink, let key = key {
                eventSink(["event": "bufferingEnd", "key": key])
            }
        } else {
            // Handle unexpected key paths or contexts gracefully
            NSLog("Unhandled key path: \(path), context: \(String(describing: context))")
        }
    }

    // Player Initialization
    // Updates playback state based on isPlaying flag
    func updatePlayingState() {
        guard isInitialized, let key = key else {
            NSLog("not initialized and paused!!")
            displayLink.isPaused = true
            return
        }
        
        // Ensure observers are added if needed
        if !_observersAdded {
            if let currentItem = player.currentItem {
                addObservers(to: currentItem)
            }
        }
        
        // Update player playback state based on isPlaying flag
        if isPlaying {
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: 1.0)
                player.rate = playerRate
            } else {
                player.play()
                player.rate = playerRate
            }
        } else {
            player.pause()
        }
        
        // Set display link appropriately, however, don't pause
        // the display link of the video isSeeking, as we don't
        // want to block the UI from updating during seeking.
        if isPlaying {
            displayLink.isPaused = !isPlaying
        } else if !isSeeking {
            displayLink.isPaused = !isPlaying
        }
    }

    // Called when the player is ready to play (initialized)
    func onReadyToPlay() {
        guard let eventSink = eventSink, 
            !isInitialized,
            let key = key,
            let currentItem = player.currentItem,
            player.status == .readyToPlay else {
            return
        }
        
        let size = currentItem.presentationSize
        let width = size.width
        let height = size.height
        
        let asset = currentItem.asset
        let onlyAudio = asset.tracks(withMediaType: .video).isEmpty
        
        // The player has not yet initialized.
        if !onlyAudio && height == CGSize.zero.height && width == CGSize.zero.width {
            return
        }
        
        let isLive = CMTIME_IS_INDEFINITE(currentItem.duration)
        // The player may be initialized but still needs to determine the duration.
        if !isLive && duration() == 0 {
            return
        }
        
        // Fix from https://github.com/flutter/flutter/issues/66413
        guard let track = player.currentItem?.tracks.first,
            let assetTrack = track.assetTrack else {
            return
        }
        
        // Get the natural size and apply the preferred transform to get the real size
        let naturalSize = assetTrack.naturalSize
        let prefTrans = assetTrack.preferredTransform
        let realSize = naturalSize.applying(prefTrans)
        
        // Mark as initialized and set up for playback
        isInitialized = true
        addVideoOutput()
        updatePlayingState()
        
        // Send initialized event to Flutter with video dimensions
        eventSink([
            "event": "initialized",
            "duration": NSNumber(value: duration()),
            "width": NSNumber(value: abs(realSize.width) != 0 ? abs(realSize.width) : width),
            "height": NSNumber(value: abs(realSize.height) != 0 ? abs(realSize.height) : height),
            "key": key
        ])
    }

    // Playback Control Methods
    // Start playing the video
    func play() {
        stalledCount = 0
        isPlaying = true
        guard isInitialized, let key = key else {
            NSLog("not initialized and paused!!")
            displayLink.isPaused = true
            return
        }
        
        // Ensure observers are added if needed
        if !_observersAdded {
            if let currentItem = player.currentItem {
                addObservers(to: currentItem)
            }
        }

        if #available(iOS 10.0, *) {
            player.playImmediately(atRate: 1.0)
            player.rate = playerRate
        } else {
            player.play()
            player.rate = playerRate
        }

        displayLink.isPaused = !isPlaying
        
        // iOS 10+ workaround to ensure playback starts correctly
        if #available(iOS 10.0, *) {
            if let currentItem = player.currentItem {
                player.replaceCurrentItem(with: currentItem)
            }
        }
    }

    // Pause the video
    func pause() {
        isPlaying = false
        guard isInitialized, let key = key else {
            NSLog("not initialized and paused!!")
            displayLink.isPaused = true
            return
        }
        
        // Ensure observers are added if needed
        if !_observersAdded {
            if let currentItem = player.currentItem {
                addObservers(to: currentItem)
            }
        }

        player.pause()

        displayLink.isPaused = !isPlaying
    }

    // returns whether the video is currently playing
    func getIsPlaying() -> Bool {
        return isPlaying
    }

    // Get the current playback position in milliseconds
    func position() -> Int64 {
        return FLTCMTimeToMillis(player.currentTime())
    }

    // Get the absolute timestamp for live streams
    func absolutePosition() -> Int64 {
        if let currentDate = player.currentItem?.currentDate() {
            return FLTNSTimeIntervalToMillis(currentDate.timeIntervalSince1970)
        }
        return 0
    }

    // Get the total duration of the video in milliseconds
    func duration() -> Int64 {
        var time: CMTime
        
        if #available(iOS 13, *) {
            time = player.currentItem?.duration ?? .zero
        } else {
            time = player.currentItem?.asset.duration ?? .zero
        }
        
        // Use custom end time if set
        if let currentItem = player.currentItem,
        !CMTIME_IS_INVALID(currentItem.forwardPlaybackEndTime) {
            time = currentItem.forwardPlaybackEndTime
        }
        
        return FLTCMTimeToMillis(time)
    }

    // Seek to a specific position in milliseconds
    func seekTo(_ location: Int) {
        isSeeking = true
        displayLink.isPaused = false // to see seeking in video output
        
        // Perform the seek operation
        player.seek(to: CMTimeMake(value: Int64(location), timescale: 1000),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero) { [weak self] finished in
            
            // run async query to not run on main UI thread
            // really buggy otherwise
            let queue = DispatchQueue.global(qos: .default)
            queue.async { [weak self] in
                guard let self = self else { return }
                
                // sleep for 2 frames (time is defined by displayLink duration)
                Thread.sleep(forTimeInterval: 2 * self.displayLink.duration)
                self.isSeeking = false
                // set display link as appropriate
                self.displayLink.isPaused = !self.isPlaying
            }
        }
    }

    // Set whether the video should loop when it reaches the end
    func setIsLooping(_ isLooping: Bool) {
        self.isLooping = isLooping
    }

    // Set the volume level (0.0 to 1.0)
    func setVolume(_ volume: Double) {
        player.volume = Float(max(0.0, min(1.0, volume)))
    }

    // Set the playback speed
    func setSpeed(_ speed: Double, result: @escaping FlutterResult) {
        if speed == 1.0 || speed == 0.0 {
            playerRate = 1.0
            result(nil)
        } else if speed < 0 || speed > 2.0 {
            result(FlutterError(
                code: "unsupported_speed",
                message: "Speed must be >= 0.0 and <= 2.0",
                details: nil
            ))
        } else if (speed > 1.0 && player.currentItem?.canPlayFastForward == true) ||
                (speed < 1.0 && player.currentItem?.canPlaySlowForward == true) {
            playerRate = Float(speed)
            result(nil)
        } else {
            if speed > 1.0 {
                result(FlutterError(
                    code: "unsupported_fast_forward",
                    message: "This video cannot be played fast forward",
                    details: nil
                ))
            } else {
                result(FlutterError(
                    code: "unsupported_slow_forward",
                    message: "This video cannot be played slow forward",
                    details: nil
                ))
            }
        }
        
        // Apply rate if currently playing
        if isPlaying {
            player.rate = Float(playerRate)
        }
    }

    // Set track parameters for quality control
    func setTrackParameters(width: Int, height: Int, bitrate: Int) {
        player.currentItem?.preferredPeakBitRate = Double(bitrate)
        
        if #available(iOS 11.0, *) {
            if width == 0 && height == 0 {
                player.currentItem?.preferredMaximumResolution = .zero
            } else {
                player.currentItem?.preferredMaximumResolution = CGSize(width: width, height: height)
            }
        }
    }

    #if os(iOS)
    // Create and configure a player layer for UIKit-based rendering
    func usePlayerLayer(frame: CGRect) {
        // Create new controller passing reference to the AVPlayerLayer
        _playerLayer = AVPlayerLayer(player: player)
        
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            _playerLayer?.frame = frame
            _playerLayer?.needsDisplayOnBoundsChange = true
            // [self._playerLayer addObserver:self forKeyPath:readyForDisplayKeyPath options:NSKeyValueObservingOptionNew context:nil];
            rootViewController.view.layer.addSublayer(_playerLayer!)
            rootViewController.view.layer.needsDisplayOnBoundsChange = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Empty completion handler (keeping the same structure as Obj-C code)
            }
        }
    }
    #endif

    #if os(iOS)
    // Set the audio track by name and index
    func setAudioTrack(_ name: String, index: Int) {
        guard let currentItem = player.currentItem,
            let audioSelectionGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return
        }

        let asset = currentItem.asset  
        
        let options = audioSelectionGroup.options
        
        // Find and select the specified audio track
        for i in 0..<options.count {
            let option = options[i]
            let metaDatas = AVMetadataItem.metadataItems(from: option.commonMetadata, 
                                                        withKey: "title", 
                                                        keySpace: .common)
            
            if metaDatas.count > 0, 
            let title = metaDatas[0].stringValue,
            title == name && index == i {
                player.currentItem?.select(option, in: audioSelectionGroup)
            }
        }
    }

    // Set whether audio should mix with other apps' audio
    func setMixWithOthers(_ mixWithOthers: Bool) {
        do {
            if mixWithOthers {
                try AVAudioSession.sharedInstance().setCategory(.playback, 
                                                            options: .mixWithOthers)
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback)
            }
        } catch {
            NSLog("Failed to set audio session category: \(error.localizedDescription)")
        }
    }
    #endif

    // Texture Generation
    // Create a transparent buffer for when no frame is available
    func prevTransparentBuffer() -> CVPixelBuffer? {
        if let prevBuffer = prevBuffer {
            CVPixelBufferLockBaseAddress(prevBuffer, .init(rawValue: 0))
            
            let bufferWidth = CVPixelBufferGetWidth(prevBuffer)
            let bufferHeight = CVPixelBufferGetHeight(prevBuffer)
            
            if let baseAddress = CVPixelBufferGetBaseAddress(prevBuffer) {
                var pixel = baseAddress.assumingMemoryBound(to: UInt8.self)
                
                // Set all pixels to transparent black
                for _ in 0..<bufferHeight {
                    for _ in 0..<bufferWidth {
                        pixel[0] = 0  // B
                        pixel[1] = 0  // G
                        pixel[2] = 0  // R
                        pixel[3] = 0  // A
                        pixel += 4
                    }
                }
            }
            
            CVPixelBufferUnlockBaseAddress(prevBuffer, .init(rawValue: 0))
            return prevBuffer
        }
        return prevBuffer
    }

    // FlutterTexture Protocol Implementation
    // Copy the current video frame as a pixel buffer for Flutter rendering
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        let outputItemTime = videoOutput?.itemTime(forHostTime: CACurrentMediaTime())
        
        guard let outputTime = outputItemTime else { return nil }
        
        if videoOutput?.hasNewPixelBuffer(forItemTime: outputTime) == true {
            failedCount = 0
            if let buffer = videoOutput?.copyPixelBuffer(forItemTime: outputTime, itemTimeForDisplay: nil) {
                prevBuffer = buffer
                return Unmanaged.passRetained(buffer)
            }
            return nil
        } else {
            // AVPlayerItemVideoOutput.hasNewPixelBufferForItemTime doesn't work correctly
            failedCount += 1
            if failedCount > 100 {
                failedCount = 0
                removeVideoOutput()
                addVideoOutput()
            }
            
            // Return the previous buffer if available
            if let buffer = prevBuffer {
                return Unmanaged.passRetained(buffer)
            }
            return nil
        }
    }

    // Texture Lifecycle
    // Called when the texture is unregistered
    func onTextureUnregistered() {
        DispatchQueue.main.async { [weak self] in
            self?.dispose()
        }
    }

    // FlutterStreamHandler Protocol Implementation
    // Called when event listening is cancelled
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // Called when Flutter starts listening for events
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        
        // TODO(@recastrodiaz): remove the line below when the race condition is resolved:
        // https://github.com/flutter/flutter/issues/21483
        // This line ensures the 'initialized' event is sent when the event
        // 'AVPlayerItemStatusReadyToPlay' fires before eventSink is set (this function
        // onListen is called)
        onReadyToPlay()
        
        return nil
    }

    // Disposal
    /// This method allows you to dispose without touching the event channel.  This
    /// is useful for the case where the Engine is in the process of deconstruction
    /// so the channel is going to die or is already dead.
    func disposeSansEventChannel() {
        do {
            clear()
            displayLink.invalidate()
        } catch let exception as NSException {
            NSLog("%@", exception.debugDescription)
        } catch {
            NSLog("Unknown error during disposal")
        }
    }

    // Fully dispose of the player and its resources
    func dispose() {
        disposeSansEventChannel()
        eventChannel?.setStreamHandler(nil)
        disposed = true
    }
}

// FLTBetterPlayerPlugin
// Main plugin class that interfaces with Flutter
public class FLTBetterPlayerPlugin: NSObject, FlutterPlugin {
    // Properties
    private weak var registry: FlutterTextureRegistry?
    private weak var messenger: FlutterBinaryMessenger?
    private var players: [Int64: FLTBetterPlayer] = [:]
    private weak var registrar: FlutterPluginRegistrar?
    private var cacheManager: CacheManager
    
    // Static properties that were class variables in Objective-C
    private static var dataSourceDict: [String: Any] = [:]
    private static var timeObserverIdDict: [String: Any] = [:]
    private static var artworkImageDict: [String: MPMediaItemArtwork] = [:]
    
    // Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "better_player_channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = FLTBetterPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.publish(instance)
    }

    // Initialization
    init(registrar: FlutterPluginRegistrar) {
        self.registry = registrar.textures()
        self.messenger = registrar.messenger()
        self.registrar = registrar
        self.players = [:]
        
        // Initialize dictionaries
        FLTBetterPlayerPlugin.timeObserverIdDict = [:]
        FLTBetterPlayerPlugin.artworkImageDict = [:]
        FLTBetterPlayerPlugin.dataSourceDict = [:]
        
        // Start HTTP cache
        do {
            try KTVHTTPCache.proxyStart()
        } catch {
            print("Failed to start KTVHTTPCache proxy: \(error)")
        }

        // Initialize cache manager
        self.cacheManager = CacheManager()
        
        super.init()
    }

    // Plugin Lifecycle
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        // Clean up all players when the plugin is detached
        for (textureId, player) in players {
            player.disposeSansEventChannel()
        }
        players.removeAll()
    }

    // Player Setup
    // Set up a new player instance and register it with Flutter
    func onPlayerSetup(_ player: FLTBetterPlayer,
                  frameUpdater: FLTFrameUpdater,
                  result: @escaping FlutterResult) {
        guard let registry = registry else {
            result(FlutterError(code: "player_setup_failed", 
                            message: "Registry is not available", 
                            details: nil))
            return
        }
        
        // Register the player with the texture registry
        let textureId = registry.register(player)
        frameUpdater.textureId = textureId
        
        // Create event channel for this specific texture
        let channelName = "better_player_channel/videoEvents\(textureId)"
        guard let messenger = messenger else {
            print("BinaryMessenger is nil")
            return
        }

        let eventChannel = FlutterEventChannel(
            name: channelName,
            binaryMessenger: messenger
        )

        // Configure the player
        player.setMixWithOthers(false)
        eventChannel.setStreamHandler(player)
        player.eventChannel = eventChannel
        players[textureId] = player
        
        // Return the texture ID to Flutter
        result(["textureId": NSNumber(value: textureId)])
    }

    // Remote Control and Notification Setup
    // Set up remote control notifications for the player
    func setupRemoteNotification(for player: FLTBetterPlayer) {
        stopOtherUpdateListener(for: player)
        
        guard let textureId = getTextureId(player: player),
            let dataSource = FLTBetterPlayerPlugin.dataSourceDict[textureId] as? [String: Any] else {
            return
        }
        
        var showNotification = false
        if let showNotificationObject = dataSource["showNotification"],
        !(showNotificationObject is NSNull) {
            showNotification = (dataSource["showNotification"] as? Bool) ?? false
        }
        
        let title = dataSource["title"] as? String ?? ""
        let author = dataSource["author"] as? String ?? ""
        let imageUrl = dataSource["imageUrl"] as? String
        
        if showNotification {
            setRemoteCommandsNotificationActive()
            setupRemoteCommands(for: player)
            setupRemoteCommandNotification(player: player, title: title, author: author, imageUrl: imageUrl)
            setupUpdateListener(player: player, title: title, author: author, imageUrl: imageUrl)
        }
    }

    // Activate the audio session for remote control commands
    func setRemoteCommandsNotificationActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            NSLog("Failed to activate audio session: %@", error.localizedDescription)
        }
    }

    // Deactivate the audio session when no more players are active
    func setRemoteCommandsNotificationNotActive() {
        do {
            if players.isEmpty {
                try AVAudioSession.sharedInstance().setActive(false)
            }
            UIApplication.shared.endReceivingRemoteControlEvents()
        } catch {
            NSLog("Failed to deactivate audio session: %@", error.localizedDescription)
        }
    }

    // Set up remote control commands (play, pause, etc.)
    func setupRemoteCommands(for player: FLTBetterPlayer) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Enable relevant commands
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
        }
        
        // Add handlers for each command
        commandCenter.togglePlayPauseCommand.addTarget { [weak player] event in
            guard let player = player else { return .commandFailed }
            
            if player.isPlaying {
                player.eventSink?(["event": "play"])
            } else {
                player.eventSink?(["event": "pause"])
            }
            return .success
        }
        
        commandCenter.playCommand.addTarget { [weak player] event in
            guard let player = player else { return .commandFailed }
            
            player.eventSink?(["event": "play"])
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak player] event in
            guard let player = player else { return .commandFailed }
            
            player.eventSink?(["event": "pause"])
            return .success
        }
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget { [weak player] event in
                guard let player = player,
                    let playbackEvent = event as? MPChangePlaybackPositionCommandEvent else {
                    return .commandFailed
                }
                
                let time = CMTimeMake(value: Int64(playbackEvent.positionTime), timescale: 1)
                let millis = FLTCMTimeToMillis(time)
                
                player.seekTo(Int(millis))
                player.eventSink?(["event": "seek", "position": NSNumber(value: millis)])
                
                return .success
            }
        }
    }

    // Set up the control center/lock screen media info
    func setupRemoteCommandNotification(player: FLTBetterPlayer, title: String, author: String, imageUrl: String?) {
        let positionInSeconds = Float(player.position()) / 1000.0
        let durationInSeconds = Float(player.duration()) / 1000.0
        
        // Create the now playing info dict with basic metadata
        var nowPlayingInfoDict: [String: Any] = [
            MPMediaItemPropertyArtist: author,
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionInSeconds,
            MPMediaItemPropertyPlaybackDuration: durationInSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        
        // Handle artwork image if provided
        if let imageUrl = imageUrl, !(imageUrl is NSNull) {
            if let key = getTextureId(player: player),
               !(key is NSNull) {
                
                if let artworkImage = FLTBetterPlayerPlugin.artworkImageDict[key] {
                    // Use cached artwork image if available
                    nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artworkImage
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
                } else {
                    // Load artwork image asynchronously
                    let queue = DispatchQueue.global(qos: .default)
                    queue.async {
                        do {
                            var tempArtworkImage: UIImage?
                            
                            if (!imageUrl.contains("http")) {
                                // Local file
                                tempArtworkImage = UIImage(contentsOfFile: imageUrl)
                            } else {
                                // Remote URL
                                if let nsImageUrl = URL(string: imageUrl),
                                   let imageData = try? Data(contentsOf: nsImageUrl) {
                                    tempArtworkImage = UIImage(data: imageData)
                                }
                            }
                            
                            if let tempArtworkImage = tempArtworkImage {
                                let artworkImage = MPMediaItemArtwork(image: tempArtworkImage)
                                FLTBetterPlayerPlugin.artworkImageDict[key] = artworkImage
                                nowPlayingInfoDict[MPMediaItemPropertyArtwork] = artworkImage
                            }
                            
                            DispatchQueue.main.async {
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
                            }
                        } catch {
                            // Handle exceptions silently as in Obj-C version
                        }
                    }
                }
            }
        } else {
            // No artwork image, just set the info dict
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
        }
    }

    // Helper to get the texture ID string for a player
    func getTextureId(player: FLTBetterPlayer) -> String? {
        // Find the key (textureId) for the given player
        for (id, p) in players {
            if p === player {
                return String(id)
            }
        }
        return nil
    }
    
    // Set up periodic updates for lock screen info
    func setupUpdateListener(player: FLTBetterPlayer, title: String, author: String, imageUrl: String?) {
        let timeObserverId = player.player.addPeriodicTimeObserver(
            forInterval: CMTimeMake(value: 1, timescale: 1),
            queue: nil
        ) { [weak self] time in
            guard let self = self else { return }
            self.setupRemoteCommandNotification(
                player: player, 
                title: title, 
                author: author, 
                imageUrl: imageUrl
            )
        }
        
        // Store the observer for later removal
        if let key = getTextureId(player: player) {
            FLTBetterPlayerPlugin.timeObserverIdDict[key] = timeObserverId
        }
    }

    // Clean up notification data for a player
    func disposeNotificationData(for player: FLTBetterPlayer) {
        guard let key = getTextureId(player: player) else { return }
        
        if let timeObserverId = FLTBetterPlayerPlugin.timeObserverIdDict[key] {
            FLTBetterPlayerPlugin.timeObserverIdDict.removeValue(forKey: key)
            FLTBetterPlayerPlugin.artworkImageDict.removeValue(forKey: key)
            
            player.player.removeTimeObserver(timeObserverId)
        }
        
        // Clear lock screen/control center media info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }

    // Stop update listeners for other players when a new one is started
    func stopOtherUpdateListener(for player: FLTBetterPlayer) {
        guard let currentPlayerTextureId = getTextureId(player: player) else { return }
        
        for textureId in FLTBetterPlayerPlugin.timeObserverIdDict.keys {
            // Skip the current player
            if currentPlayerTextureId == textureId {
                continue
            }

            if let timeObserverId = FLTBetterPlayerPlugin.timeObserverIdDict[textureId],
            let textureIdInt = Int64(textureId), 
            let playerToRemoveListener = players[textureIdInt] as? FLTBetterPlayer {
                playerToRemoveListener.player.removeTimeObserver(timeObserverId)
            }
        }

        FLTBetterPlayerPlugin.timeObserverIdDict.removeAll()
    }

    // Flutter Method Channel Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "init" {
            // Allow audio playback when the Ring/Silent switch is set to silent
            for (textureId, player) in players {
                registry?.unregisterTexture(textureId)
                player.dispose()
            }
            
            players.removeAll()
            result(nil)
        } else if call.method == "create" {
            guard let registry = registry else {
                result(FlutterError(code: "player_creation_failed", message: "Registry is not available", details: nil))
                return
            }
            
            let frameUpdater = FLTFrameUpdater(registry: registry)
            let player = FLTBetterPlayer(frameUpdater: frameUpdater)
            onPlayerSetup(player, frameUpdater: frameUpdater, result: result)
        } else {
            guard let argsMap = call.arguments as? [String: Any],
                  let textureIdValue = argsMap["textureId"] as? NSNumber,
                  let player = players[textureIdValue.int64Value] as? FLTBetterPlayer else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            let textureId = textureIdValue.int64Value
            
            switch call.method {
            case "setDataSource":
                // Clear existing player and prepare for new data source
                player.clear()
                // This call will clear cached frame because we will return transparent frame
                registry?.textureFrameAvailable(textureId)
                
                guard let dataSource = argsMap["dataSource"] as? [String: Any] else {
                    result(FlutterMethodNotImplemented)
                    return
                }
                
                // Store data source info for later reference (e.g., notifications)
                if let textureIdString = getTextureId(player: player) {
                    FLTBetterPlayerPlugin.dataSourceDict[textureIdString] = dataSource
                }
                
                let assetArg = dataSource["asset"] as? String
                let uriArg = dataSource["uri"] as? String
                let key = dataSource["key"] as? String ?? ""
                
                var headers = dataSource["headers"] as? [String: String] ?? [:]
                
                var overriddenDuration = 0
                if let overriddenDurationValue = dataSource["overriddenDuration"],
                   !(overriddenDurationValue is NSNull) {
                    overriddenDuration = (dataSource["overriddenDuration"] as? Int) ?? 0
                }
                
                var useCache = false
                if let useCacheObject = dataSource["useCache"],
                   !(useCacheObject is NSNull) {
                    useCache = (dataSource["useCache"] as? Bool) ?? false
                }
                
                // Set up data source based on asset or URI
                if let assetArg = assetArg {
                    var assetPath: String?
                    if let package = dataSource["package"] as? String,
                       !(package is NSNull) {
                        assetPath = registrar?.lookupKey(forAsset: assetArg, fromPackage: package)
                    } else {
                        assetPath = registrar?.lookupKey(forAsset: assetArg)
                    }
                    
                    if let assetPath = assetPath {
                        player.setDataSourceAsset(assetPath, withKey: key, overriddenDuration: overriddenDuration)
                    }
                    result(nil)
                } else if let uriArg = uriArg {
                    if uriArg.hasPrefix("file://") {
                        if let url = URL(string: uriArg) {
                            player.setDataSourceURL(url, withKey: key, withHeaders: headers, withCache: useCache, overriddenDuration: overriddenDuration)
                        }
                    } else {
                        if let proxyURL = cacheManager.getCacheUrl(uriArg as NSString) as? URL {
                            player.setDataSourceURL(proxyURL, withKey: key, withHeaders: headers, withCache: useCache, overriddenDuration: overriddenDuration)
                        }
                    }
                    result(nil)
                } else {
                    result(FlutterMethodNotImplemented)
                }
                
            case "dispose":
                // Dispose the player and clean up resources
                player.clear()
                disposeNotificationData(for: player)
                setRemoteCommandsNotificationNotActive()
                registry?.unregisterTexture(textureId)
                players.removeValue(forKey: textureId)
                
                // If the Flutter contains https://github.com/flutter/engine/pull/12695,
                // the `player` is disposed via `onTextureUnregistered` at the right time.
                // Without https://github.com/flutter/engine/pull/12695, there is no guarantee that the
                // texture has completed the un-reregistration. It may leads a crash if we dispose the
                // `player` before the texture is unregistered. We add a dispatch_after hack to make sure the
                // texture is unregistered before we dispose the `player`.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak player] in
                    if let player = player, !player.disposed {
                        player.dispose()
                    }
                }
                
                if players.isEmpty {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
                result(nil)
                
            case "setLooping":
                // Configure looping behavior
                if let looping = argsMap["looping"] as? Bool {
                    player.setIsLooping(looping)
                }
                result(nil)
                
            case "setVolume":
                // Set player volume
                if let volume = argsMap["volume"] as? Double {
                    player.setVolume(volume)
                }
                result(nil)
                
            case "play":
                // Start playback and set up remote notifications
                setupRemoteNotification(for: player)
                player.play()
                result(nil)
                
            case "position":
                // Get current playback position
                result(NSNumber(value: player.position()))
                
            case "absolutePosition":
                // Get absolute position (for live streams)
                result(NSNumber(value: player.absolutePosition()))
                
            case "seekTo":
                // Seek to specific position
                if let location = argsMap["location"] as? Int {
                    player.seekTo(location)
                }
                result(nil)
                
            case "pause":
                // Pause playback
                player.pause()
                result(nil)

            case "getIsPlaying":
                // Check if the player is currently playing, return boolean
                result(player.getIsPlaying())
            
            case "setTrackParameters":
                // Set video quality parameters
                let width = argsMap["width"] as? Int ?? 0
                let height = argsMap["height"] as? Int ?? 0
                let bitrate = argsMap["bitrate"] as? Int ?? 0
                
                player.setTrackParameters(width: width, height: height, bitrate: bitrate)
                result(nil)
                
            case "setAudioTrack":
                // Select specific audio track
                if let name = argsMap["name"] as? String,
                   let index = argsMap["index"] as? Int {
                    player.setAudioTrack(name, index: index)
                }
                result(nil)
                
            case "setMixWithOthers":
                // Configure audio mixing behavior
                if let mixWithOthers = argsMap["mixWithOthers"] as? Bool {
                    player.setMixWithOthers(mixWithOthers)
                }
                result(nil)
                
            case "clearCache":
                // Clear video cache
                KTVHTTPCache.cacheDeleteAllCaches()
                result(nil)
                
            case "preCache":
                // Pre-cache a video for future playback
                if let url = argsMap["dataSource"] as? String {
                    cacheManager.preCache(url as NSString)
                }
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}