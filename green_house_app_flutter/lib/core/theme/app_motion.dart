import 'package:flutter/material.dart';

/// Design tokens: Motion durations and curves.
///
/// Motion is only used to explain a status change (relay on/off, data
/// freshness), never as decoration. Durations stay in the 150–320ms band.
abstract final class AppMotion {
  /// Micro feedback (chip colour, icon swap).
  static const Duration fast = Duration(milliseconds: 150);

  /// Default transition (value cross-fade, card state).
  static const Duration base = Duration(milliseconds: 220);

  /// Larger surface change (banner slide, skeleton → content).
  static const Duration slow = Duration(milliseconds: 320);

  /// Standard easing for entering / settling content.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasised easing for state changes that must be noticed.
  static const Curve emphasized = Curves.easeInOutCubic;

  /// True when the platform asks for reduced motion
  /// (`MediaQuery.disableAnimations`, set by Android's "Remove animations"
  /// and iOS "Reduce Motion"). Callers must collapse to [Duration.zero] when
  /// this returns true.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
