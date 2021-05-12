import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

class TheBetterPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    BetterPlayerController ctl = BetterPlayerController(
      BetterPlayerConfiguration(aspectRatio: 16 / 9, autoPlay: true, looping: true),
      betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Example player"),
      ),
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(
          controller: ctl,
        ),
      ),
    );
  }
}
