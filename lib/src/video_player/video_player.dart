// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Dart imports:
import 'dart:async';
import 'dart:io';

// Project imports:
import 'package:better_player/src/video_player/video_player_platform_interface.dart';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';

final VideoPlayerPlatform _videoPlayerPlatform = VideoPlayerPlatform.instance
// This will clear all open videos on the platform when a full restart is
// performed.
  ..init();

/// The duration, current position, buffering state, error state and settings
/// of a [VideoPlayerController].
class VideoPlayerValue {
  /// Constructs a video with the given values. Only [duration] is required. The
  /// rest will initialize with default values when unset.
  VideoPlayerValue({
    required this.duration,
    this.size,
    this.position = const Duration(),
    this.absolutePosition,
    this.buffered = const <DurationRange>[],
    this.isPlaying = false,
    this.isLooping = false,
    this.isBuffering = false,
    this.volume = 1.0,
    this.errorDescription,
  });

  /// Returns an instance with a `null` [Duration].
  VideoPlayerValue.uninitialized() : this(duration: null);

  /// Returns an instance with a `null` [Duration] and the given
  /// [errorDescription].
  VideoPlayerValue.erroneous(String errorDescription)
      : this(duration: null, errorDescription: errorDescription);

  /// The total duration of the video.
  ///
  /// Is null when [initialized] is false.
  final Duration? duration;

  /// The current playback position.
  final Duration position;

  /// The current absolute playback position.
  ///
  /// Is null when is not available.
  final DateTime? absolutePosition;

  /// The currently buffered ranges.
  final List<DurationRange> buffered;

  /// True if the video is playing. False if it's paused.
  final bool isPlaying;

  /// True if the video is looping.
  final bool isLooping;

  /// True if the video is currently buffering.
  final bool isBuffering;

  /// The current volume of the playback.
  final double volume;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is [null].
  final String? errorDescription;

  /// The [size] of the currently loaded video.
  ///
  /// Is null when [initialized] is false.
  final Size? size;

  /// Indicates whether or not the video has been loaded and is ready to play.
  bool get initialized => duration != null;

  /// Indicates whether or not the video is in an error state. If this is true
  /// [errorDescription] should have information about the problem.
  bool get hasError => errorDescription != null;

  /// Returns [size.width] / [size.height] when size is non-null, or `1.0.` when
  /// size is null or the aspect ratio would be less than or equal to 0.0.
  double get aspectRatio {
    if (size == null) {
      return 1.0;
    }
    final double aspectRatio = size!.width / size!.height;
    if (aspectRatio <= 0) {
      return 1.0;
    }
    return aspectRatio;
  }

  /// Returns a new instance that has the same values as this current instance,
  /// except for any overrides passed in as arguments to [copyWidth].
  VideoPlayerValue copyWith({
    Duration? duration,
    Size? size,
    Duration? position,
    DateTime? absolutePosition,
    List<DurationRange>? buffered,
    bool? isPlaying,
    bool? isLooping,
    bool? isBuffering,
    double? volume,
    String? errorDescription,
  }) {
    return VideoPlayerValue(
      duration: duration ?? this.duration,
      size: size ?? this.size,
      position: position ?? this.position,
      absolutePosition: absolutePosition ?? this.absolutePosition,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      volume: volume ?? this.volume,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }

  @override
  String toString() {
    // ignore: no_runtimetype_tostring
    return '$runtimeType('
        'duration: $duration, '
        'size: $size, '
        'position: $position, '
        'absolutePosition: $absolutePosition, '
        'buffered: [${buffered.join(', ')}], '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering, '
        'volume: $volume, '
        'errorDescription: $errorDescription)';
  }
}

/// Controls a platform video player, and provides updates when the state is
/// changing.
///
/// Instances must be initialized with initialize.
///
/// The video is displayed in a Flutter app by creating a [VideoPlayer] widget.
///
/// To reclaim the resources used by the player call [dispose].
///
/// After [dispose] all further calls are ignored.
class VideoPlayerController extends ValueNotifier<VideoPlayerValue> {
  /// Constructs a [VideoPlayerController] and creates video controller on platform side.
  VideoPlayerController() : super(VideoPlayerValue(duration: null)) {
    _create();
  }

  final StreamController<VideoEvent> videoEventStreamController =
      StreamController.broadcast();
  final Completer<void> _creatingCompleter = Completer<void>();
  int? _textureId;

  Timer? _timer;
  bool _isDisposed = false;
  late Completer<void> _initializingCompleter;
  StreamSubscription<dynamic>? _eventSubscription;

  bool get _created => _creatingCompleter.isCompleted;

  /// This is just exposed for testing. It shouldn't be used by anyone depending
  /// on the plugin.
  @visibleForTesting
  int? get textureId => _textureId;

  /// Attempts to open the given [dataSource] and load metadata about the video.
  Future<void> _create() async {
    _textureId = await _videoPlayerPlatform.create();
    _creatingCompleter.complete(null);

    unawaited(_applyLooping());

    void eventListener(VideoEvent event) {
      if (_isDisposed) {
        return;
      }
      videoEventStreamController.add(event);
      switch (event.eventType) {
        case VideoEventType.initialized:
          value = value.copyWith(
            duration: event.duration,
            size: event.size,
          );
          _initializingCompleter.complete(null);
          _applyPlayPause();
          break;
        case VideoEventType.completed:
          value = value.copyWith(isPlaying: false, position: value.duration);
          _timer?.cancel();
          break;
        case VideoEventType.bufferingUpdate:
          value = value.copyWith(buffered: event.buffered);
          break;
        case VideoEventType.bufferingStart:
          value = value.copyWith(isBuffering: true);
          break;
        case VideoEventType.bufferingEnd:
          if (value.isBuffering) {
            value = value.copyWith(isBuffering: false);
          }
          break;

        case VideoEventType.play:
          play();
          break;
        case VideoEventType.pause:
          pause();
          break;
        case VideoEventType.seek:
          seekTo(event.position);
          break;
        case VideoEventType.unknown:
          break;
      }
    }

    void errorListener(Object object) {
      if (object is PlatformException) {
        final PlatformException e = object;
        value = value.copyWith(errorDescription: e.message);
        //value = VideoPlayerValue.erroneous(e.message);
      } else {
        //value = VideoPlayerValue.erroneous(object.toString());
        value.copyWith(errorDescription: object.toString());
      }
      _timer?.cancel();
      if (!_initializingCompleter.isCompleted) {
        _initializingCompleter.completeError(object);
      }
    }

    _eventSubscription = _videoPlayerPlatform
        .videoEventsFor(_textureId)
        .listen(eventListener, onError: errorListener);
  }

  /// Set data source for playing a video from an asset.
  ///
  /// The name of the asset is given by the [dataSource] argument and must not be
  /// null. The [package] argument must be non-null when the asset comes from a
  /// package and null otherwise.
  Future<void> setAssetDataSource(
    String dataSource, {
    String? package,
    bool? showNotification,
    String? title,
    String? author,
    String? imageUrl,
    String? notificationChannelName,
    Duration? overriddenDuration,
    String? activityName,
  }) {
    return _setDataSource(
      DataSource(
        sourceType: DataSourceType.asset,
        asset: dataSource,
        package: package,
        showNotification: showNotification,
        title: title,
        author: author,
        imageUrl: imageUrl,
        notificationChannelName: notificationChannelName,
        overriddenDuration: overriddenDuration,
        activityName: activityName,
      ),
    );
  }

  /// Set data source for playing a video from obtained from
  /// the network.
  ///
  /// The URI for the video is given by the [dataSource] argument and must not be
  /// null.
  /// **Android only**: The [formatHint] option allows the caller to override
  /// the video format detection code.
  Future<void> setNetworkDataSource(
    String dataSource, {
    VideoFormat? formatHint,
    Map<String, String?>? headers,
    bool useCache = false,
    int? maxCacheSize,
    int? maxCacheFileSize,
    bool? showNotification,
    String? title,
    String? author,
    String? imageUrl,
    String? notificationChannelName,
    Duration? overriddenDuration,
    String? licenseUrl,
    Map<String, String>? drmHeaders,
    String? activityName,
  }) {
    return _setDataSource(
      DataSource(
        sourceType: DataSourceType.network,
        uri: dataSource,
        formatHint: formatHint,
        headers: headers,
        useCache: useCache,
        maxCacheSize: maxCacheSize,
        maxCacheFileSize: maxCacheFileSize,
        showNotification: showNotification,
        title: title,
        author: author,
        imageUrl: imageUrl,
        notificationChannelName: notificationChannelName,
        overriddenDuration: overriddenDuration,
        licenseUrl: licenseUrl,
        drmHeaders: drmHeaders,
        activityName: activityName,
      ),
    );
  }

  /// Set data source for playing a video from a file.
  ///
  /// This will load the file from the file-URI given by:
  /// `'file://${file.path}'`.
  Future<void> setFileDataSource(
    File file, {
    bool? showNotification,
    String? title,
    String? author,
    String? imageUrl,
    String? notificationChannelName,
    Duration? overriddenDuration,
    String? activityName,
  }) {
    return _setDataSource(
      DataSource(
          sourceType: DataSourceType.file,
          uri: 'file://${file.path}',
          showNotification: showNotification,
          title: title,
          author: author,
          imageUrl: imageUrl,
          notificationChannelName: notificationChannelName,
          overriddenDuration: overriddenDuration,
          activityName: activityName),
    );
  }

  Future<void> _setDataSource(DataSource dataSourceDescription) async {
    if (_isDisposed) {
      return;
    }

    value = VideoPlayerValue(
      duration: null,
      isLooping: value.isLooping,
      volume: value.volume,
    );

    if (!_creatingCompleter.isCompleted) await _creatingCompleter.future;

    _initializingCompleter = Completer<void>();

    await VideoPlayerPlatform.instance
        .setDataSource(_textureId, dataSourceDescription);
    return _initializingCompleter.future;
  }

  @override
  Future<void> dispose() async {
    await _creatingCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      value = VideoPlayerValue.uninitialized();
      _timer?.cancel();
      await _eventSubscription?.cancel();
      await _videoPlayerPlatform.dispose(_textureId);
      videoEventStreamController.close();
    }
    _isDisposed = true;
    super.dispose();
  }

  /// Starts playing the video.
  ///
  /// This method returns a future that completes as soon as the "play" command
  /// has been sent to the platform, not when playback itself is totally
  /// finished.
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
    await _applyPlayPause();
  }

  /// Sets whether or not the video should loop after playing once. See also
  /// [VideoPlayerValue.isLooping].
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
    await _applyLooping();
  }

  /// Pauses the video.
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> _applyLooping() async {
    if (!_created || _isDisposed) {
      return;
    }
    await _videoPlayerPlatform.setLooping(_textureId, value.isLooping);
  }

  Future<void> _applyPlayPause() async {
    if (!_created || _isDisposed) {
      return;
    }
    _timer?.cancel();
    if (value.isPlaying) {
      await _videoPlayerPlatform.play(_textureId);
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (Timer timer) async {
          if (_isDisposed) {
            return;
          }
          final Duration? newPosition = await position;
          final DateTime? newAbsolutePosition = await absolutePosition;
          // ignore: invariant_booleans
          if (_isDisposed) {
            return;
          }
          _updatePosition(newPosition, absolutePosition: newAbsolutePosition);
        },
      );
    } else {
      await _videoPlayerPlatform.pause(_textureId);
    }
  }

  // sets video volume to 0
  Future<void> mute() async {
    await _videoPlayerPlatform.setVolume(_textureId, 0);
  }

  // sets video volume to max (i.e. 1)
  Future<void> unmute() async {
    await _videoPlayerPlatform.setVolume(_textureId, 1.0);
  }

  /// The position in the current video.
  Future<Duration?> get position async {
    if (!value.initialized && _isDisposed) {
      return null;
    }
    return _videoPlayerPlatform.getPosition(_textureId);
  }

  /// The absolute position in the current video stream
  /// (i.e. EXT-X-PROGRAM-DATE-TIME in HLS).
  Future<DateTime?> get absolutePosition async {
    if (!value.initialized && _isDisposed) {
      return null;
    }
    return _videoPlayerPlatform.getAbsolutePosition(_textureId);
  }

  /// Sets the video's current timestamp to be at [moment]. The next
  /// time the video is played it will resume from the given [moment].
  ///
  /// If [moment] is outside of the video's full range it will be automatically
  /// and silently clamped.
  Future<void> seekTo(Duration? position) async {
    if (_isDisposed) {
      return;
    }

    Duration? positionToSeek = position;
    if (position! > value.duration!) {
      positionToSeek = value.duration;
    } else if (position < const Duration()) {
      positionToSeek = const Duration();
    }
    await _videoPlayerPlatform.seekTo(_textureId, positionToSeek);
    _updatePosition(position);
  }

  /// Sets the video track parameters of [this]
  ///
  /// [width] specifies width of the selected track
  /// [height] specifies height of the selected track
  /// [bitrate] specifies bitrate of the selected track
  Future<void> setTrackParameters(int? width, int? height, int? bitrate) async {
    await _videoPlayerPlatform.setTrackParameters(
        _textureId, width, height, bitrate);
  }

  void _updatePosition(Duration? position, {DateTime? absolutePosition}) {
    value = value.copyWith(position: position);
    value = value.copyWith(absolutePosition: absolutePosition);
  }

  void refresh() {
    value = value.copyWith();
  }

  void setAudioTrack(String? name, int? index) {
    _videoPlayerPlatform.setAudioTrack(_textureId, name, index);
  }

  void setMixWithOthers(bool mixWithOthers) {
    _videoPlayerPlatform.setMixWithOthers(_textureId, mixWithOthers);
  }

  static Future clearCache() async {
    return _videoPlayerPlatform.clearCache();
  }

  static Future preCache(DataSource dataSource, int preCacheSize) async {
    return _videoPlayerPlatform.preCache(dataSource, preCacheSize);
  }

  static Future stopPreCache(String url) async {
    return _videoPlayerPlatform.stopPreCache(url);
  }
}

/// Widget that displays the video controlled by [controller].
class VideoPlayer extends StatefulWidget {
  /// Uses the given [controller] for all video rendered in this widget.
  const VideoPlayer(this.controller, {Key? key}) : super(key: key);

  /// The [VideoPlayerController] responsible for the video being rendered in
  /// this widget.
  final VideoPlayerController? controller;

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  _VideoPlayerState() {
    _listener = () {
      final int? newTextureId = widget.controller!.textureId;
      if (newTextureId != _textureId) {
        setState(() {
          _textureId = newTextureId;
        });
      }
    };
  }

  late VoidCallback _listener;
  int? _textureId;

  @override
  void initState() {
    super.initState();
    _textureId = widget.controller!.textureId;
    // Need to listen for initialization events since the actual texture ID
    // becomes available after asynchronous initialization finishes.
    widget.controller!.addListener(_listener);
  }

  @override
  void didUpdateWidget(VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller!.removeListener(_listener);
    _textureId = widget.controller!.textureId;
    widget.controller!.addListener(_listener);
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.controller!.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    return _textureId == null
        ? Container()
        : _videoPlayerPlatform.buildView(_textureId);
  }
}
