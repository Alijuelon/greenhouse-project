import 'package:flutter/material.dart';

/// Design tokens: Border radius extracted from Stitch Tailwind config.
abstract final class AppRadius {
  static const double defaultRadius = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;
  static const double xl2 = 20.0;
  static const double xl3 = 24.0;
  static const double xl4 = 28.0;
  static const double full = 9999.0;

  // ─── Pre-built BorderRadius ────────────────────────────
  static final BorderRadius radiusDefault = BorderRadius.circular(
    defaultRadius,
  );
  static final BorderRadius radiusLg = BorderRadius.circular(lg);
  static final BorderRadius radiusXl = BorderRadius.circular(xl);
  static final BorderRadius radiusXl2 = BorderRadius.circular(xl2);
  static final BorderRadius radiusXl3 = BorderRadius.circular(xl3);
  static final BorderRadius radiusXl4 = BorderRadius.circular(xl4);
  static final BorderRadius radiusFull = BorderRadius.circular(full);

  /// Modal/bottom-sheet top corners (rounded-t-2xl = 16px)
  static const BorderRadius radiusTopSheet = BorderRadius.vertical(
    top: Radius.circular(16),
  );
}
