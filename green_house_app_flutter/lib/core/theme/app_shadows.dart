import 'package:flutter/material.dart';

/// Design tokens: Shadow / elevation extracted from Stitch CSS.
abstract final class AppShadows {
  /// AppBar — subtle bottom shadow
  static const BoxShadow appBar = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 1),
  );

  /// BottomNavBar — subtle top shadow
  static const BoxShadow bottomNav = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 12,
    offset: Offset(0, -1),
  );

  /// Cards (shadow-sm)
  static const BoxShadow cardSm = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  /// Dashboard card at rest (shadow-xs) — barely-there lift off [AppColors.canvas].
  static const BoxShadow cardXs = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  /// Dashboard card on press / focused state (shadow-lg).
  static const BoxShadow cardRaised = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  /// Hero gradient card — blue-green ambient glow matching AI Dosing hero.
  static const BoxShadow hero = BoxShadow(
    color: Color(0x661565C0),
    blurRadius: 24,
    offset: Offset(0, 10),
    spreadRadius: -4,
  );

  /// Hero card / elevated cards (shadow-md)
  static const BoxShadow cardMd = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 6,
    offset: Offset(0, 4),
  );

  /// Bottom sheet (shadow-2xl)
  static const BoxShadow bottomSheet = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 50,
    offset: Offset(0, 25),
  );
}
