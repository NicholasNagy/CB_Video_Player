// Flutter imports:
// Project imports:
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

///Configuration of Better Player. Allows to setup general behavior of player.
///Master configuration which contains children that configure specific part
///of player.
class BetterPlayerConfiguration {
  /// Play the video as soon as it's displayed
  final bool autoPlay;

  /// Start video at a certain position
  final Duration? startAt;

  /// Whether or not the video should loop
  final bool looping;

  /// When the video playback runs  into an error, you can build a custom
  /// error message.
  final Widget Function(BuildContext context, String? errorMessage)?
      errorBuilder;

  /// The Aspect Ratio of the Video. Important to get the correct size of the
  /// video!
  ///
  /// Will fallback to fitting within the space allowed.
  final double? aspectRatio;

  /// The placeholder is displayed underneath the Video before it is initialized
  /// or played.
  final Widget? placeholder;

  /// Should the placeholder be shown until play is pressed
  final bool showPlaceholderUntilPlay;

  /// Placeholder position of player stack. If false, then placeholder will be
  /// displayed on the bottom, so user need to hide it manually. Default is
  /// true.
  final bool placeholderOnTop;

  /// A widget which is placed between the video and the controls
  final Widget? overlay;

  /// Defines a event listener where video player events will be send
  final Function(BetterPlayerEvent)? eventListener;

  ///Defines controls configuration
  final BetterPlayerControlsConfiguration controlsConfiguration;

  ///Defines fit of the video, allows to fix video stretching, see possible
  ///values here: https://api.flutter.dev/flutter/painting/BoxFit-class.html
  final BoxFit fit;

  ///Defines rotation of the video in degrees. Default value is 0. Can be 0, 90, 180, 270.
  ///Angle will rotate only video box, controls will be in the same place.
  final double rotation;

  ///Defines function which will react on player visibility changed
  final Function(double visibilityFraction)? playerVisibilityChangedBehavior;

  ///Defines flag which enables/disables lifecycle handling (pause on app closed,
  ///play on app resumed). Default value is true.
  final bool handleLifecycle;

  ///Defines flag which enabled/disabled auto dispose of
  ///[BetterPlayerController] on [BetterPlayer] dispose. When it's true and
  ///[BetterPlayerController] instance has been attached to [BetterPlayer] widget
  ///and dispose has been called on [BetterPlayer] instance, then
  ///[BetterPlayerController] will be disposed.
  ///Default value is true.
  final bool autoDispose;

  const BetterPlayerConfiguration({
    this.aspectRatio,
    this.autoPlay = false,
    this.startAt,
    this.looping = false,
    this.placeholder,
    this.showPlaceholderUntilPlay = false,
    this.placeholderOnTop = true,
    this.overlay,
    this.errorBuilder,
    this.eventListener,
    this.controlsConfiguration = const BetterPlayerControlsConfiguration(),
    this.fit = BoxFit.fill,
    this.rotation = 0,
    this.playerVisibilityChangedBehavior,
    this.handleLifecycle = true,
    this.autoDispose = true,
  });

  BetterPlayerConfiguration copyWith({
    double? aspectRatio,
    bool? autoPlay,
    Duration? startAt,
    bool? looping,
    Widget? placeholder,
    bool? showPlaceholderUntilPlay,
    bool? placeholderOnTop,
    Widget? overlay,
    bool? showControlsOnInitialize,
    Widget Function(BuildContext context, String? errorMessage)? errorBuilder,
    Function(BetterPlayerEvent)? eventListener,
    BetterPlayerControlsConfiguration? controlsConfiguration,
    BoxFit? fit,
    double? rotation,
    Function(double visibilityFraction)? playerVisibilityChangedBehavior,
  }) {
    return BetterPlayerConfiguration(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      autoPlay: autoPlay ?? this.autoPlay,
      startAt: startAt ?? this.startAt,
      looping: looping ?? this.looping,
      placeholder: placeholder ?? this.placeholder,
      showPlaceholderUntilPlay:
          showPlaceholderUntilPlay ?? this.showPlaceholderUntilPlay,
      placeholderOnTop: placeholderOnTop ?? this.placeholderOnTop,
      overlay: overlay ?? this.overlay,
      errorBuilder: errorBuilder ?? this.errorBuilder,
      eventListener: eventListener ?? this.eventListener,
      controlsConfiguration:
          controlsConfiguration ?? this.controlsConfiguration,
      fit: fit ?? this.fit,
      rotation: rotation ?? this.rotation,
      playerVisibilityChangedBehavior: playerVisibilityChangedBehavior ??
          this.playerVisibilityChangedBehavior,
    );
  }
}
