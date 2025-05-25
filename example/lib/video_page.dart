import 'package:better_player/better_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Simple stateful widget to reproduce the bug.
/// Replaced the App() widget in the main function to run this one instead.
class VideoPage extends StatefulWidget {
  VideoPage({Key? key}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  String? path;
  List<int>? videoBytes;
  bool isLoading = true;

  // Track current page index
  int currentPageIndex = 0;

  // Store controllers with page index as key
  Map<int, BetterPlayerController> controllers = {};

  // Track play state for each video
  Map<int, bool> playingStates = {};

  String exampleManifestUrl =
      'https://replied-resources.s3.amazonaws.com/transcoded-videos/'
      'Sc9xBOOx3cblM82doaUK9rr8xYx1/dd03019b-5390-4378-9952-287122b47944/master.m3u8';

  @override
  void initState() {
    super.initState();
    setState(() {
      isLoading = true;
    });
    prepareVideo();
  }

  Future<void> prepareVideo() async {
    try {
      var content = await rootBundle.load("assets/testtest.mp4");
      Directory directory = await getApplicationDocumentsDirectory();
      path = directory.path;

      var file = File("${directory.path}/testvideo.mp4");
      file.writeAsBytesSync(content.buffer.asUint8List());

      videoBytes = file.readAsBytesSync().buffer.asUint8List();

      // Initialize first controller
      controllers[0] = createController();
      playingStates[0] = true;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error preparing video: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  BetterPlayerController createController() {
    return BetterPlayerController(
      BetterPlayerConfiguration(
        placeholderOnTop: true,
        placeholder: Center(child: CupertinoActivityIndicator()),
        aspectRatio: 9 / 16,
        autoPlay: true,
        looping: true,
        autoDispose: false,
        handleLifecycle: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enableOverflowMenu: false,
          enablePlayPause: false,
          enableMute: false,
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.file,
        "${path}/testvideo.mp4",
        bytes: videoBytes,
        videoExtension: "mp4",
      ),
    );
  }

  Future<void> togglePlayPause(int index) async {
    final controller = controllers[index];
    if (controller == null) return;

    final isPlaying = await controller.isPlaying() ?? false;

    if (isPlaying) {
      await controller.pause();
      if (mounted) {
        setState(() {
          playingStates[index] = false;
        });
      }
      print('Paused video $index');
    } else {
      await controller.play();
      if (mounted) {
        setState(() {
          playingStates[index] = true;
        });
      }
      print('Playing video $index');
    }
  }

  @override
  void dispose() {
    // Clean up all controllers
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget buildVideoPage(BuildContext context, int index) {
    // Create controller if it doesn't exist for this index
    if (!controllers.containsKey(index)) {
      controllers[index] = createController();
      playingStates[index] = true;
    }

    // Get the controller for this page
    final controller = controllers[index]!;

    // Get play state for this page
    final isPlaying = playingStates[index] ?? true;

    return CupertinoPageScaffold(
      child: GestureDetector(
        child: Stack(
          children: [
            BetterPlayer(controller: controller),
            if (!isPlaying)
              Center(
                child: Icon(
                  CupertinoIcons.play_arrow_solid,
                  size: 50,
                  color: CupertinoColors.white.withOpacity(0.8),
                ),
              )
          ],
        ),
        onTap: () => togglePlayPause(index),
      ),
    );
  }

  void onPageChanged(int index) {
    // Pause previous page's video
    if (controllers.containsKey(currentPageIndex)) {
      // controllers[currentPageIndex]?.pause();
      if (mounted) {
        setState(() {
          playingStates[currentPageIndex] = false;
        });
      }
    }

    // Play current page's video
    if (controllers.containsKey(index)) {
      controllers[index]?.play();
      if (mounted) {
        setState(() {
          playingStates[index] = true;
          currentPageIndex = index;
        });
      }
    }

    // Clean up controllers that are far away (memory management)
    cleanupDistantControllers(index);
  }

  void cleanupDistantControllers(int currentIndex) {
    // Keep only nearby controllers (current, previous, next)
    final keysToKeep = [currentIndex - 1, currentIndex, currentIndex + 1];

    final keysToDispose =
        controllers.keys.where((key) => !keysToKeep.contains(key)).toList();

    for (final key in keysToDispose) {
      controllers[key]?.dispose();
      controllers.remove(key);
      playingStates.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: isLoading
            ? Center(
                child: CupertinoActivityIndicator(),
              )
            : PageView.builder(
                itemBuilder: buildVideoPage,
                scrollDirection: Axis.vertical,
                onPageChanged: onPageChanged,
              ),
      ),
    );
  }
}
