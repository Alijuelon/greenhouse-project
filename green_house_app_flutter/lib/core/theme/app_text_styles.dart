import 'package:flutter/material.dart';

/// Design tokens: Modern geometric typography powered by Plus Jakarta Sans.
///
/// Bundled in `assets/fonts/` and declared in `pubspec.yaml`, so rendering is
/// deterministic in tests and requires no runtime download.
abstract final class AppTextStyles {
  /// Bundled Plus Jakarta Sans (weights 400–800 declared in `pubspec.yaml`).
  static TextStyle _jakarta({
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  );

  // ─── Display / Data ────────────────────────────────────
  static TextStyle get displayData => _jakarta(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 44 / 36,
    letterSpacing: -0.90,
  );

  static TextStyle get displayDataMobile => _jakarta(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 38 / 30,
    letterSpacing: -0.75,
  );

  // ─── Headlines ─────────────────────────────────────────
  static TextStyle get headlineLg => _jakarta(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 32 / 24,
    letterSpacing: -0.48,
  );

  static TextStyle get headlineMd => _jakarta(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 28 / 20,
    letterSpacing: -0.35,
  );

  static TextStyle get headlineSm => _jakarta(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 24 / 16,
    letterSpacing: -0.20,
  );

  // ─── Body ──────────────────────────────────────────────
  static TextStyle get bodyLg => _jakarta(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: -0.10,
  );

  static TextStyle get bodyMd => _jakarta(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: -0.05,
  );

  static TextStyle get bodySm =>
      _jakarta(fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12);

  // ─── Labels ────────────────────────────────────────────
  static TextStyle get labelLg => _jakarta(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: -0.05,
  );

  static TextStyle get labelMd => _jakarta(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.05,
  );

  static TextStyle get labelSm => _jakarta(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.15,
  );

  // ─── Telemetry ─────────────────────────────────────────
  static TextStyle get telemetryUnit =>
      _jakarta(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14);

  // ─── Metrics (dashboard numbers) ───────────────────────
  // Tabular figures so digits do not shift while values update every 5s.
  // `FontFeature` lives in `dart:ui` and is re-exported by
  // `package:flutter/material.dart`; a separate `dart:ui` import would trip
  // `unnecessary_import`.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Hero metric (temperature / humidity inside the gradient hero).
  static TextStyle get metricHero => _jakarta(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 40 / 34,
    letterSpacing: -0.80,
    fontFeatures: _tabular,
  );

  /// Large metric (NPK values, summary strip).
  static TextStyle get metricLg => _jakarta(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 34 / 28,
    letterSpacing: -0.60,
    fontFeatures: _tabular,
  );

  /// Medium metric (secondary sensor tiles).
  static TextStyle get metricMd => _jakarta(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    letterSpacing: -0.40,
    fontFeatures: _tabular,
  );

  // ─── Dashboard text ────────────────────────────────────
  /// All-caps eyebrow above a section ("GREENHOUSE 01").
  static TextStyle get sectionLabel => _jakarta(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 1.2,
  );

  /// Emphasised body copy (inline stat values, dialog text).
  static TextStyle get bodyStrong => _jakarta(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: -0.10,
  );

  /// Smallest supporting text (timestamps, units, hints).
  static TextStyle get caption => _jakarta(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.05,
  );
}
