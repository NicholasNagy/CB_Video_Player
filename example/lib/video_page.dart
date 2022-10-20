import 'package:better_player/better_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  ByteData k;
  List<int> necStuff;
  String path;
  bool isPlaying = true;
  String exampleManifestUrl =
      'https://replied-resources.s3.amazonaws.com/transcoded-videos/'
      'Sc9xBOOx3cblM82doaUK9rr8xYx1/dd03019b-5390-4378-9952-287122b47944/master.m3u8';
  List<BetterPlayerController> but = new List(3);
  int cI = 0;

  Future<String> dothing() async {
    var content = await rootBundle.load("assets/testtest.mp4");
    Directory directory = await getApplicationDocumentsDirectory();
    this.path = directory.path;
    var file = File("${directory.path}/testvideo.mp4");
    file.writeAsBytesSync(content.buffer.asUint8List());
    return "hi";
  }

  @override
  void initState() {
    dothing().then((ku) {
      this.necStuff = File("${this.path}/testvideo.mp4")
          .readAsBytesSync()
          .buffer
          .asUint8List();
      //print(this.necStuff);
    });
    but[0] = getController();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  BetterPlayerController getController() {
    var before = DateTime.now().microsecondsSinceEpoch;
    print(this.necStuff == null);
    var ctl = BetterPlayerController(
        BetterPlayerConfiguration(
            placeholderOnTop: true,
            placeholder: Center(child: CupertinoActivityIndicator()),
            aspectRatio: 9 / 16,
            autoPlay: true,
            looping: true,
            autoDispose: true,
            controlsConfiguration: BetterPlayerControlsConfiguration(
                showControls: false,
                enableOverflowMenu: false,
                enablePlayPause: false,
                enableMute: false)),
        betterPlayerDataSource: BetterPlayerDataSource(
            //this.necStuff == null
            //? BetterPlayerDataSourceType.network
            //: BetterPlayerDataSourceType.memory,
            BetterPlayerDataSourceType.network,
            //this.necStuff == null ? exampleManifestUrl : "",
            //bytes: this.necStuff,
            exampleManifestUrl,
            videoExtension: "mp4"));
    var after = DateTime.now().microsecondsSinceEpoch;
    print(after - before);
    return ctl;
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

  void sleepthing(BetterPlayerController prevCtl) async {
    await Future<dynamic>.delayed(Duration(seconds: 1)).then((dynamic k) {
      prevCtl?.dispose();
      prevCtl = null;
    });
  }

  Widget getNext(BuildContext ctx, int index) {
    but[(index) % 3] = getController();
    var ctl = but[index % 3];
    ctl.play();

    var prevCtl = but[(index - 1) % 3];
    prevCtl?.pause();
    sleepthing(prevCtl);

    return CupertinoPageScaffold(
      child: GestureDetector(
        child: Stack(
          children: [
            BetterPlayer(controller: ctl),
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
        onTap: () {
          BetterPlayerController.preCache(exampleManifestUrl);
          //ctl.isPlaying() ? ctl.pause() : ctl.play();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView.builder(
              itemBuilder: getNext,
              scrollDirection: Axis.vertical,
            )));
  }
}
