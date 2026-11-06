import 'package:flutter/material.dart';

/// Design tokens: Color palette extracted from Stitch Tailwind config.
/// AgriSense IoT Smart Greenhouse — Material 3 color system.
abstract final class AppColors {
  // ─── Primary & Gradients ────────────────────────────────────────────
  static const Color primary = Color(0xFF0D631B);
  static const Color primaryContainer = Color(0xFF2E7D32);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFCBFFC2);
  static const Color primaryFixed = Color(0xFFA3F69C);
  static const Color primaryFixedDim = Color(0xFF88D982);
  static const Color inversePrimary = Color(0xFF88D982);
  static const Color surfaceTint = Color(0xFF1B6D24);

  /// Signature AgriSense hero gradient (deep blue → blue → forest green → mid green),
  /// matching AI Dosing, Automation, and Settings hero cards.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF1565C0),
      Color(0xFF1B5E20),
      Color(0xFF2E7D32),
    ],
    stops: [0.0, 0.3, 0.65, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Multi-hue sweep ring around brand logos/avatars in AppBar, Hero, and Settings.
  static const SweepGradient logoRingGradient = SweepGradient(
    colors: [
      Color(0xFF4FC3F7),
      Color(0xFF69F0AE),
      Color(0xFFFFB74D),
      Color(0xFF4FC3F7),
    ],
  );

  static const LinearGradient activeCardGradient = LinearGradient(
    colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Secondary ──────────────────────────────────────────
  static const Color secondary = Color(0xFF00639A);
  static const Color secondaryContainer = Color(0xFF51B2FE);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF00436A);
  static const Color secondaryFixed = Color(0xFFCEE5FF);
  static const Color secondaryFixedDim = Color(0xFF96CCFF);

  // ─── Tertiary ───────────────────────────────────────────
  static const Color tertiary = Color(0xFF4C5665);
  static const Color tertiaryContainer = Color(0xFF646E7E);

  // ─── Surface / Background ──────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F7);
  static const Color surfaceContainer = Color(0xFFECEEF1);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EB);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E6);
  static const Color surfaceBright = Color(0xFFF7F9FC);
  static const Color background = Color(0xFFF7F9FC);
  static const Color surfaceDim = Color(0xFFD8DADD);
  static const Color surfaceVariant = Color(0xFFE0E3E6);
  static const Color surfaceBorder = Color(0xFFE5E7EB);

  // ─── On-Surface ────────────────────────────────────────
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF40493D);
  static const Color onBackground = Color(0xFF191C1E);
  static const Color inverseSurface = Color(0xFF2D3133);
  static const Color inverseOnSurface = Color(0xFFEFF1F4);

  // ─── Outline ───────────────────────────────────────────
  static const Color outline = Color(0xFF707A6C);
  static const Color outlineVariant = Color(0xFFBFCABA);

  // ─── Error ─────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ─── Semantic: Warning / Danger / Success / Info ───────
  //
  // `warning`, `success`, `info` and `accent` are FILL-ONLY tokens: saturated
  // fills, badge/chip backgrounds, icons and >=22px metric numerals. Measured
  // on white they are 2.04:1 / 4.12:1 / 3.86:1 / 3.19:1, so they must NEVER
  // carry small text on a light surface. `danger` does clear AA on white
  // (4.98:1) but drops to 4.36:1 on [dangerSurface], i.e. it is tint-unsafe.
  // For any text or icon label in these hues use the `*Ink` tokens below, which
  // are gated at >= 4.5:1 on BOTH [card] and their own soft surface.
  static const Color warning = Color(0xFFFFA000);
  static const Color warningSurface = Color(0xFFFFF8E1);
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerSurface = Color(0xFFFFEBEE);
  static const Color success = Color(0xFF388E3C);
  static const Color successSurface = Color(0xFFE8F5E9);
  static const Color info = Color(0xFF0288D1);
  static const Color infoSurface = Color(0xFFE1F5FE);

  // ─── Semantic ink: text-safe partners of the fills ─────
  //
  // Same hue family as the fill tokens above, darkened until every one clears
  // the WCAG AA body floor (4.5:1) on BOTH [card] and its own soft surface.
  // Measured (card / own surface):
  //   warningInk 5.93 / 5.58 on warningSurface
  //   successInk 6.43 / 5.72 on successSurface
  //   infoInk    7.21 / 6.42 on infoSurface
  //   dangerInk  6.54 / 5.72 on dangerSurface
  //   accentInk  7.08 / 6.24 on accentSoft
  // Re-measure with test/theme/contrast_test.dart; those numbers are asserted.
  static const Color warningInk = Color(0xFF8A5A00);
  static const Color successInk = Color(0xFF2E6B32);
  static const Color infoInk = Color(0xFF0B5C8A);
  static const Color dangerInk = Color(0xFFB3261E);

  // ─── Dashboard surfaces & accent ───────────────────────
  /// App canvas behind dashboard cards (soft botanical off-white).
  static const Color canvas = Color(0xFFF4F7F2);

  /// Card / tile surface on [canvas].
  static const Color card = Color(0xFFFFFFFF);

  /// Muted inner surface (inset tiles, empty states).
  static const Color cardMuted = Color(0xFFEFF4EC);

  /// 1px card hairline border.
  static const Color cardBorder = Color(0xFFE2E8DE);

  /// Interactive accent (relay on-state, active nav item).
  /// FILL-ONLY: 3.19:1 against white — UI-component/large-text use only, never
  /// small text. Use [accentInk] for text or icons in this hue.
  static const Color accent = Color(0xFF2FA36B);

  /// Tinted background that pairs with [accent].
  static const Color accentSoft = Color(0xFFE3F5EA);

  /// Text-safe partner of [accent]: 7.08:1 on [card], 6.24:1 on [accentSoft].
  static const Color accentInk = Color(0xFF16653F);

  // ─── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);

  /// 5.61:1 on white / 5.03:1 on [cardMuted] — passes WCAG AA for body text.
  static const Color textMuted = Color(0xFF5F6B5C);
}
