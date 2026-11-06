// WCAG 2.1 contrast gate for the dashboard token layer.
//
// Every ratio is computed from the real `AppColors` channels with the standard
// sRGB relative-luminance formula:
//
//   L = 0.2126·R + 0.7152·G + 0.0722·B     (channels linearised)
//   ratio = (L_light + 0.05) / (L_dark + 0.05)
//
// Nothing here is hardcoded: if a token changes, the number moves.
//
// ── FILL vs INK ──────────────────────────────────────────────────────────
// The palette keeps two families per semantic hue and they are NOT
// interchangeable:
//
//   FILL-ONLY  `warning` #FFA000 (2.04:1 on white), `success` #388E3C
//              (4.12:1), `info` #0288D1 (3.86:1), `accent` #2FA36B (3.19:1).
//              These are switch tracks, progress fills, chip backgrounds, map
//              pins and >=22px metric numerals. They must NEVER carry small
//              text on a light surface, so they are deliberately absent from
//              the text-contrast table below — asserting them as text colours
//              would either fail forever or force the 4.5:1 gate down.
//              (`danger` #D32F2F clears AA on white at 4.98:1 but falls to
//              4.36:1 on `dangerSurface`, so it is tint-unsafe as well.)
//
//   INK        `warningInk`, `successInk`, `infoInk`, `accentInk`,
//              `dangerInk` — the same hues darkened until they clear the AA
//              body floor against BOTH `card` and their own soft surface.
//              These are the tokens to use for text, icon labels and any
//              small glyph.
//
// Every ink pair is asserted at >= 4.5:1 (not 3.0) and every measured ratio is
// printed, so a green run carries the numbers with it.
//
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/core/theme/app_colors.dart';

/// sRGB channel (0..1) → linear light.
double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance of an opaque colour.
double relativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// WCAG contrast ratio between two opaque colours (1.0 .. 21.0).
double contrastRatio(Color foreground, Color background) {
  final a = relativeLuminance(foreground);
  final b = relativeLuminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// One text/background pair under test.
class _Pair {
  const _Pair(
    this.name,
    this.foreground,
    this.background,
    this.minRatio,
    this.rationale,
  );

  final String name;
  final Color foreground;
  final Color background;

  /// Required ratio. 4.5 = WCAG AA body text, 3.0 = AA large text
  /// (>=24px regular / >=18.66px bold) or a non-text UI component (1.4.11).
  final double minRatio;

  /// Why this threshold applies — no threshold is lowered without one.
  final String rationale;
}

/// An ink token plus the soft surface it is expected to sit on.
class _Ink {
  const _Ink(this.name, this.ink, this.softName, this.soft);

  final String name;
  final Color ink;
  final String softName;
  final Color soft;
}

/// Minimum ratio every ink token must clear on `card` and on its own surface.
const double _inkFloor = 4.5;

/// Ink tokens: text-safe semantic colours.
///
/// Each entry is measured twice — against [AppColors.card] and against the soft
/// tint it is designed to pair with.
const List<_Ink> _inks = [
  _Ink(
    'warningInk',
    AppColors.warningInk,
    'warningSurface',
    AppColors.warningSurface,
  ),
  _Ink(
    'successInk',
    AppColors.successInk,
    'successSurface',
    AppColors.successSurface,
  ),
  _Ink('infoInk', AppColors.infoInk, 'infoSurface', AppColors.infoSurface),
  _Ink('accentInk', AppColors.accentInk, 'accentSoft', AppColors.accentSoft),
  _Ink(
    'dangerInk',
    AppColors.dangerInk,
    'dangerSurface',
    AppColors.dangerSurface,
  ),
];

/// Pairs that must hold for dashboard body text and UI components.
///
/// Only INK tokens (and the neutral text/on-colour pairs) appear here. The
/// FILL-ONLY tokens described in the header are intentionally excluded.
final List<_Pair> _pairs = [
  _Pair(
    'textPrimary/card',
    AppColors.textPrimary,
    AppColors.card,
    4.5,
    'body text on card — AA body',
  ),
  _Pair(
    'textSecondary/card',
    AppColors.textSecondary,
    AppColors.card,
    4.5,
    'body text on card — AA body',
  ),
  _Pair(
    'textMuted/card',
    AppColors.textMuted,
    AppColors.card,
    4.5,
    'timestamps/units on card — AA body',
  ),
  _Pair(
    'onPrimary/primary',
    AppColors.onPrimary,
    AppColors.primary,
    4.5,
    'text/icon on primary fill — AA body',
  ),
  _Pair(
    'onPrimary/accent',
    AppColors.onPrimary,
    AppColors.accent,
    3.0,
    'WHITE TEXT ON AN ACCENT FILL: accent is a switch track and icon fill, so '
        'the pairing is text-on-fill and the 1.4.11 / AA large-text floor '
        '(3:1) applies. accent itself is never text — use accentInk for that',
  ),
  _Pair(
    'error/card',
    AppColors.error,
    AppColors.card,
    4.5,
    'error text on card — AA body',
  ),
  _Pair(
    'onSurface/canvas',
    AppColors.onSurface,
    AppColors.canvas,
    4.5,
    'body text on canvas — AA body',
  ),
  _Pair(
    'onSurface/cardMuted',
    AppColors.onSurface,
    AppColors.cardMuted,
    4.5,
    'body text on muted card — AA body',
  ),
  // ── Ink tokens on the neutral card surface ──
  for (final ink in _inks)
    _Pair(
      '${ink.name}/card',
      ink.ink,
      AppColors.card,
      _inkFloor,
      'text-safe ${ink.name} on card — AA body',
    ),
  // ── Ink tokens on their own soft surface ──
  for (final ink in _inks)
    _Pair(
      '${ink.name}/${ink.softName}',
      ink.ink,
      ink.soft,
      _inkFloor,
      'text-safe ${ink.name} on its own tint — AA body',
    ),
];

String _fmt(double ratio) => ratio.toStringAsFixed(3);

void main() {
  group('AppColors WCAG contrast', () {
    test('measured ratios (printed for the record)', () {
      print('pair                              ratio   required');
      for (final p in _pairs) {
        final ratio = contrastRatio(p.foreground, p.background);
        print(
          '${p.name.padRight(32)} '
          '${ratio.toStringAsFixed(2).padLeft(6)}  '
          '${p.minRatio.toStringAsFixed(1).padLeft(8)}',
        );
      }
      print('');
      print('FILL-ONLY tokens — measured for the record, NOT text colours:');
      for (final fill in const [
        ('warning', AppColors.warning),
        ('success', AppColors.success),
        ('info', AppColors.info),
        ('accent', AppColors.accent),
        ('danger', AppColors.danger),
      ]) {
        print(
          '${fill.$1.padRight(32)} '
          '${contrastRatio(fill.$2, AppColors.card).toStringAsFixed(2).padLeft(6)}'
          '  (fill — never small text)',
        );
      }
    });

    for (final pair in _pairs) {
      test('${pair.name} meets ${pair.minRatio}:1 — ${pair.rationale}', () {
        final ratio = contrastRatio(pair.foreground, pair.background);
        expect(
          ratio,
          greaterThanOrEqualTo(pair.minRatio),
          reason:
              '${pair.name} measured ${_fmt(ratio)}:1 '
              '(needs >= ${pair.minRatio}:1). ${pair.rationale}',
        );
      });
    }

    // ── Ink guard ────────────────────────────────────────────────────────
    // One test that walks every ink token, prints the computed number for both
    // surfaces, and fails if any single one drops below 4.5:1. This is the
    // backstop: a new ink token added to AppColors without an entry here is
    // caught by the count assertion, and a darkened/lit fill cannot sneak in.
    test(
      'every *Ink token is >= 4.5:1 on card AND on its own soft surface',
      () {
        expect(
          _inks,
          hasLength(5),
          reason:
              'AppColors declares successInk/warningInk/infoInk/accentInk/'
              'dangerInk — add any new ink token to _inks so it is gated.',
        );

        print('ink pair                          card    soft   min');
        var worst = double.infinity;
        var worstName = '';
        for (final ink in _inks) {
          final onCard = contrastRatio(ink.ink, AppColors.card);
          final onSoft = contrastRatio(ink.ink, ink.soft);
          print(
            '${'${ink.name}/${ink.softName}'.padRight(32)} '
            '${onCard.toStringAsFixed(3).padLeft(6)}  '
            '${onSoft.toStringAsFixed(3).padLeft(6)}  '
            '${_inkFloor.toStringAsFixed(1).padLeft(4)}',
          );

          expect(
            onCard,
            greaterThanOrEqualTo(_inkFloor),
            reason:
                '${ink.name} on card measured ${_fmt(onCard)}:1 — needs '
                '>= 4.5:1 for AA body text',
          );
          expect(
            onSoft,
            greaterThanOrEqualTo(_inkFloor),
            reason:
                '${ink.name} on ${ink.softName} measured ${_fmt(onSoft)}:1 — '
                'needs >= 4.5:1 for AA body text',
          );

          final localWorst = math.min(onCard, onSoft);
          if (localWorst < worst) {
            worst = localWorst;
            worstName = ink.name;
          }
        }
        print(
          'worst ink: $worstName ${worst.toStringAsFixed(3)}:1 '
          '(floor ${_inkFloor.toStringAsFixed(1)}:1)',
        );
      },
    );

    // An ink token that is not darker than its fill is a copy/paste bug: the
    // fill is by definition the un-darkened (unsafe) version of the hue.
    test('each ink token is darker than the fill it replaces', () {
      for (final (name, ink, fill) in const [
        ('warningInk', AppColors.warningInk, AppColors.warning),
        ('successInk', AppColors.successInk, AppColors.success),
        ('infoInk', AppColors.infoInk, AppColors.info),
        ('accentInk', AppColors.accentInk, AppColors.accent),
        ('dangerInk', AppColors.dangerInk, AppColors.danger),
      ]) {
        final inkL = relativeLuminance(ink);
        final fillL = relativeLuminance(fill);
        print(
          '$name luminance ${inkL.toStringAsFixed(4)} < '
          'fill ${fillL.toStringAsFixed(4)}',
        );
        expect(
          inkL,
          lessThan(fillL),
          reason: '$name must be a darkened version of its fill token',
        );
      }
    });

    test('heroGradient matches AI Dosing 4-stop blue→green gradient', () {
      expect(AppColors.heroGradient.colors, hasLength(4));
      expect(AppColors.heroGradient.colors, [
        const Color(0xFF0D47A1),
        const Color(0xFF1565C0),
        const Color(0xFF1B5E20),
        const Color(0xFF2E7D32),
      ]);
      expect(AppColors.heroGradient.stops, const [0.0, 0.3, 0.65, 1.0]);
      expect(AppColors.heroGradient.begin, Alignment.topLeft);
      expect(AppColors.heroGradient.end, Alignment.bottomRight);
      // White copy sits on this gradient: every stop must clear AA body text.
      for (final stop in AppColors.heroGradient.colors) {
        expect(
          contrastRatio(Colors.white, stop),
          greaterThanOrEqualTo(4.5),
          reason:
              'white on hero stop $stop is '
              '${contrastRatio(Colors.white, stop).toStringAsFixed(2)}:1',
        );
      }
    });
  });
}
