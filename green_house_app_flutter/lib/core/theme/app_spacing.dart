/// Design tokens: Spacing scale extracted from Stitch Tailwind config.
abstract final class AppSpacing {
  static const double space2xs = 2.0;
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double space2xl = 32.0;

  /// Page-level horizontal margin
  static const double margin = 16.0;

  /// Medium page margin (used in analytics/settings)
  static const double marginMd = 20.0;

  /// Grid gutter
  static const double gutter = 16.0;

  /// Small grid gutter
  static const double gutterSm = 12.0;

  // ─── App shell ─────────────────────────────────────────
  /// Visible AppBar height (excluding the status-bar inset).
  static const double appBarHeight = 64.0;

  /// AppBar slot reserved in the shell body inset: [appBarHeight] + breathing
  /// room below it.
  static const double appBarOuterHeight = 80.0;

  /// Visible bottom navigation bar height (excluding the system inset).
  static const double navBarHeight = 66.0;

  /// Bottom navigation slot reserved in the shell body inset:
  /// [navBarHeight] + breathing room above it.
  static const double navBarOuterHeight = 86.0;

  /// Minimum accessible touch target (Material / WCAG 2.5.8).
  static const double minTapTarget = 48.0;

  /// Gap between the shell AppBar slot and the first page section.
  static const double pageTopGap = 12.0;
}
