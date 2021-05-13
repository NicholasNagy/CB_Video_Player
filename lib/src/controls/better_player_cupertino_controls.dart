// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:flutter/material.dart';

// Project imports:
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/video_player/video_player.dart';

class BetterPlayerCupertinoControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerCupertinoControls({
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerCupertinoControlsState();
  }
}

class _BetterPlayerCupertinoControlsState
    extends BetterPlayerControlsState<BetterPlayerCupertinoControls> {
  final marginSize = 5.0;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;

  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    _betterPlayerController = BetterPlayerController.of(context);
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    return GestureDetector(
      onDoubleTap: () {
        // The double Tap PlayPause
        _onPlayPause();
      },
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;

    if (_oldController != _betterPlayerController) {
      _dispose();
    }

    super.didChangeDependencies();
  }

  void _onPlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _betterPlayerController!.pause();
      } else {
        if (!_controller!.value.initialized) {
          if (_betterPlayerController!.betterPlayerDataSource?.liveStream ==
              true) {
            _betterPlayerController!.play();
          }
        } else {
          _betterPlayerController!.play();
        }
      }
    });
  }
}
