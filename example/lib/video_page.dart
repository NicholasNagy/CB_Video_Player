import 'package:better_player/better_player.dart';
import 'package:flutter/cupertino.dart';

/// Simple stateful widget to reproduce the bug.
/// Replaced the App() widget in the main function to run this one instead.
///
/// The issue can be noticed when the Play Icon will still be there (means that the video should be paused)
/// and the video will continue playing.
class VideoPage extends StatefulWidget {
  VideoPage({Key key}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  BetterPlayerController controller;
  bool isPlaying = true;
  String exampleManifestUrl =
      'https://replied-resources.s3.amazonaws.com/transcoded-videos/'
      'Sc9xBOOx3cblM82doaUK9rr8xYx1/dd03019b-5390-4378-9952-287122b47944/master.m3u8';

  @override
  void initState() {
    controller = getController();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  BetterPlayerController getController() {
    return BetterPlayerController(
        BetterPlayerConfiguration(
            placeholderOnTop: true,
            placeholder: Center(child: CupertinoActivityIndicator()),
            aspectRatio: 9 / 16,
            autoPlay: true,
            looping: true,
            autoDispose: false,
            controlsConfiguration: BetterPlayerControlsConfiguration(
                showControls: false,
                enableOverflowMenu: false,
                enablePlayPause: false,
                enableMute: false)),
        betterPlayerDataSource: BetterPlayerDataSource(
            BetterPlayerDataSourceType.network, exampleManifestUrl));
  }

  Future<void> toggleController(BetterPlayerController controller) async {
    if (controller.isPlaying()) {
      await controller.pause().then((value) => print('Paused'));
      setState(() {
        isPlaying = false;
      });
    } else {
      await controller.play().then((value) => print('Played'));
      setState(() {
        isPlaying = true;
      });
    }
    print('Controller is playing? ${controller.isPlaying()}');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        child: GestureDetector(
          child: Stack(
            children: [
              BetterPlayer(controller: controller),
              if (!isPlaying)
                Center(
                  child: Icon(
                    CupertinoIcons.play_arrow_solid,
                    size: 50,
                    color: CupertinoColors.black,
                  ),
                )
            ],
          ),
          onTap: () async {
            await toggleController(controller);
          },
        ),
      ),
    );
  }
}
