// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:better_player/better_player.dart';

// Project imports:
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

///UI configuration of Better Player. Allows to change colors/icons/behavior
///of controls. Used in BetterPlayerConfiguration. Configuration applies only
///for player displayed in app, not in notification.
class BetterPlayerControlsConfiguration {
  ///Color of the control bars
  final Color controlBarColor;

  ///Color of texts
  final Color textColor;

  ///Color of icons
  final Color iconsColor;

  ///Icon of play
  final IconData playIcon;

  ///Icon of pause
  final IconData pauseIcon;

  ///Icon of mute
  final IconData muteIcon;

  ///Icon of unmute
  final IconData unMuteIcon;

  ///Cupertino only icon, icon of skip
  final IconData skipBackIcon;

  ///Cupertino only icon, icon of forward
  final IconData skipForwardIcon;

  ///Flag used to enable/disable mute
  final bool enableMute;

  ///Flag used to enable/disable progress texts
  final bool enableProgressText;

  ///Flag used to enable/disable progress bar
  final bool enableProgressBar;

  ///Flag used to enable/disable progress bar drag
  final bool enableProgressBarDrag;

  ///Flag used to enable/disable play-pause
  final bool enablePlayPause;

  ///Flag used to enable skip forward and skip back
  final bool enableSkips;

  ///Progress bar played color
  final Color progressBarPlayedColor;

  ///Progress bar circle color
  final Color progressBarHandleColor;

  ///Progress bar buffered video color
  final Color progressBarBufferedColor;

  ///Progress bar background color
  final Color progressBarBackgroundColor;

  ///Time to hide controls
  final Duration controlsHideTime;

  ///Parameter used to build custom controls
  final Widget Function(BetterPlayerController controller)?
      customControlsBuilder;

  ///Parameter used to change theme of the player
  final BetterPlayerTheme? playerTheme;

  ///Flag used to show/hide controls
  final bool showControls;

  ///Flag used to show controls on init
  final bool showControlsOnInitialize;

  ///Control bar height
  final double controlBarHeight;

  ///Live text color;
  final Color liveTextColor;

  ///Flag used to show/hide overflow menu which contains playback,
  ///qualities options.
  final bool enableOverflowMenu;

  ///Flag used to show/hide qualities
  final bool enableQualities;

  ///Flag used to enable/disable retry feature
  final bool enableRetry;

  ///Flag used to show/hide audio tracks
  final bool enableAudioTracks;

  ///Icon of the overflow menu
  final IconData overflowMenuIcon;

  ///Icon of the qualities menu item from overflow menu
  final IconData qualitiesIcon;

  ///Icon of the audios menu item from overflow menu
  final IconData audioTracksIcon;

  ///Color of overflow menu icons
  final Color overflowMenuIconsColor;

  ///Time which will be used once user uses forward
  final int forwardSkipTimeInMilliseconds;

  ///Time which will be used once user uses backward
  final int backwardSkipTimeInMilliseconds;

  ///Color of default loading indicator
  final Color loadingColor;

  ///Widget which can be used instead of default progress
  final Widget? loadingWidget;

  ///Color of the background, when no frame is displayed.
  final Color backgroundColor;

  ///Color of the bottom modal sheet used for overflow menu items.
  final Color overflowModalColor;

  ///Color of text in bottom modal sheet used for overflow menu items.
  final Color overflowModalTextColor;

  const BetterPlayerControlsConfiguration(
      {this.controlBarColor = Colors.black87,
      this.textColor = Colors.white,
      this.iconsColor = Colors.white,
      this.playIcon = Icons.play_arrow,
      this.pauseIcon = Icons.pause,
      this.muteIcon = Icons.volume_up,
      this.unMuteIcon = Icons.volume_mute,
      this.skipBackIcon = Icons.fast_rewind,
      this.skipForwardIcon = Icons.fast_forward,
      this.enableMute = true,
      this.enableProgressText = true,
      this.enableProgressBar = true,
      this.enableProgressBarDrag = true,
      this.enablePlayPause = true,
      this.enableSkips = true,
      this.enableAudioTracks = true,
      this.progressBarPlayedColor = Colors.white,
      this.progressBarHandleColor = Colors.white,
      this.progressBarBufferedColor = Colors.white70,
      this.progressBarBackgroundColor = Colors.white60,
      this.controlsHideTime = const Duration(milliseconds: 300),
      this.customControlsBuilder,
      this.playerTheme,
      this.showControls = true,
      this.showControlsOnInitialize = true,
      this.controlBarHeight = 48.0,
      this.liveTextColor = Colors.red,
      this.enableOverflowMenu = true,
      this.enableQualities = true,
      this.enableRetry = true,
      this.overflowMenuIcon = Icons.more_vert,
      this.qualitiesIcon = Icons.hd,
      this.audioTracksIcon = Icons.audiotrack,
      this.overflowMenuIconsColor = Colors.black,
      this.forwardSkipTimeInMilliseconds = 15000,
      this.backwardSkipTimeInMilliseconds = 15000,
      this.loadingColor = Colors.white,
      this.loadingWidget,
      this.backgroundColor = Colors.black,
      this.overflowModalColor = Colors.white,
      this.overflowModalTextColor = Colors.black});

  factory BetterPlayerControlsConfiguration.white() {
    return const BetterPlayerControlsConfiguration(
        controlBarColor: Colors.white,
        textColor: Colors.black,
        iconsColor: Colors.black,
        progressBarPlayedColor: Colors.black,
        progressBarHandleColor: Colors.black,
        progressBarBufferedColor: Colors.black54,
        progressBarBackgroundColor: Colors.white70);
  }

  factory BetterPlayerControlsConfiguration.cupertino() {
    return const BetterPlayerControlsConfiguration(
        playIcon: CupertinoIcons.play_arrow_solid,
        pauseIcon: CupertinoIcons.pause_solid);
  }
}
