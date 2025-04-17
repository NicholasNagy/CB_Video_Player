import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

class TheBetterPlayer extends StatefulWidget {
  @override
  _BetterPlayerState createState() => _BetterPlayerState();
}

class _BetterPlayerState extends State<TheBetterPlayer> {
  BetterPlayerController? ctl;

  @override
  Widget build(BuildContext context) {
    ctl = BetterPlayerController(
      BetterPlayerConfiguration(
          aspectRatio: 9 / 16, autoPlay: false, looping: true),
      betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"),
    );

    return Scaffold(
      body: AspectRatio(
        aspectRatio: 9 / 16,
        child: BetterPlayer(
          controller: ctl!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    ctl?.dispose();
  }
}
