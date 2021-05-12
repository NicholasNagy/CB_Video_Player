// Dart imports:
import 'dart:async';
import 'dart:ui' as ui;

// Flutter imports:
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:flutter/material.dart';

// Project imports:
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
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
  double? _latestVolume;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;
  bool _wasLoading = false;

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

    final backgroundColor = _controlsConfiguration.controlBarColor;
    final iconColor = _controlsConfiguration.iconsColor;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    final barHeight = _controlsConfiguration.controlBarHeight;
    final buttonPadding = 16.0;
    return GestureDetector(
      onDoubleTap: () {
        // The double Tap PlayPause
        _onPlayPause();
      },
      child: AbsorbPointer(
        child: Column(
          children: <Widget>[
            _buildTopBar(backgroundColor, iconColor, barHeight, buttonPadding),
            if (_wasLoading)
              Expanded(child: Center(child: _buildLoadingWidget()))
            else
              _buildHitArea(),
            _buildBottomBar(backgroundColor, iconColor, barHeight),
          ],
        ),
      ),
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

  Widget _buildBottomBar(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.bottomCenter,
        margin: EdgeInsets.all(marginSize),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 10.0,
              sigmaY: 10.0,
            ),
            child: Container(
              height: barHeight,
              color: backgroundColor,
              child: _betterPlayerController!.isLiveStream()
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const SizedBox(width: 8),
                        if (_controlsConfiguration.enablePlayPause)
                          _buildPlayPause(_controller!, iconColor, barHeight)
                        else
                          const SizedBox(),
                        const SizedBox(width: 8),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        const SizedBox(),
                        if (_controlsConfiguration.enablePlayPause)
                          _buildPlayPause(_controller!, iconColor, barHeight)
                        else
                          const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        if (_controlsConfiguration.enableProgressBar)
                          _buildProgressBar()
                        else
                          const SizedBox(),
                        const SizedBox()
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Expanded _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(
    VideoPlayerController controller,
    Color iconColor,
    double barHeight,
  ) {
    return GestureDetector(
      onTap: _onPlayPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildTopBar(
    Color backgroundColor,
    Color iconColor,
    double barHeight,
    double buttonPadding,
  ) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      height: barHeight,
      margin: EdgeInsets.only(
        top: marginSize,
        right: marginSize,
        left: marginSize,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(),
          const SizedBox(),
          Expanded(child: Container()),
          const SizedBox(),
          const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: BetterPlayerCupertinoVideoProgressBar(
          _controller,
          _betterPlayerController,
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
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

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  "Retry",
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return _controlsConfiguration.loadingWidget;
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
