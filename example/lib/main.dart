import 'better_player.dart';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  List<BetterPlayerController> controllers = [];

  Widget getNext(BuildContext context, int index) {
    controllers[(index - 2) % 5].dispose();
    controllers[(index - 2) % 5] = createController();
    controllers[index % 5].play();
    return BetterPlayer(controller: controllers[index % 5]);
  }

  BetterPlayerController createController() {
    return BetterPlayerController(
      BetterPlayerConfiguration(
          aspectRatio: 9 / 16, autoPlay: false, looping: true),
      betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          "https://storage.googleapis.com/app-videos-11720/transcoded-videos/20rFDl3kyAVwmhz8Blr2gU4q8Z93/20secondcalc2/video_master.m3u8"),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (int number = 0; number < 5; number++) {
      controllers.add(createController());
    }

    return MaterialApp(
        home: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView.builder(
              itemBuilder: getNext,
              scrollDirection: Axis.vertical,
            )));
  }
}
