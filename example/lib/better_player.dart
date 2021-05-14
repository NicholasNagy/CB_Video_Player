import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

class TheBetterPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    BetterPlayerController ctl = BetterPlayerController(
      BetterPlayerConfiguration(
          aspectRatio: 16 / 9, autoPlay: true, looping: true),
      betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"),
    );

    return Scaffold(
      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(
          controller: ctl,
        ),
      ),
    );
  }
}
