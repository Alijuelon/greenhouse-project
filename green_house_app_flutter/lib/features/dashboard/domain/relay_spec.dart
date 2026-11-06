import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';

/// Single source of truth for one actuator channel.
///
/// The ESP32 firmware owns the channel order, so [index] must stay in sync
/// with `target_relays` / `relays` from `/api/dashboard/live`:
/// `0` Dosing A, `1` Dosing B, `2` pH Up, `3` pH Down, `4` Exhaust Blower,
/// `5` Pompa Irigasi.
///
/// [accent] is a FILL-ONLY colour (tint, switch track, large glyph);
/// [ink] is its text-safe partner and must be used for any small icon or label
/// in the same hue.
@immutable
class RelaySpec {
  const RelaySpec({
    required this.index,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.accent,
    required this.ink,
    required this.isProtected,
    required this.description,
  });

  /// Channel number on the ESP32 (0-based).
  final int index;

  /// Full display name, e.g. `Dosing Pupuk A`.
  final String name;

  /// Compact name for narrow grid cells, e.g. `Pupuk A`.
  final String shortName;

  final IconData icon;

  /// Saturated fill colour. Never carries small text.
  final Color accent;

  /// Text-safe partner of [accent] (>= 4.5:1 on card and on its tint).
  final Color ink;

  /// `true` when a manual ON command needs an explicit confirmation because it
  /// changes the nutrient solution (dosing pumps, pH adjusters).
  final bool isProtected;

  /// Why the channel is protected. Empty for unprotected channels.
  final String description;

  /// Spec for channel [i]; throws [RangeError] outside `0..5`.
  static RelaySpec byIndex(int i) => relaySpecs[i];
}

/// The six actuator channels, in ESP32 order.
const List<RelaySpec> relaySpecs = [
  RelaySpec(
    index: 0,
    name: 'Dosing Pupuk A',
    shortName: 'Pupuk A',
    icon: Icons.colorize_rounded,
    accent: AppColors.success,
    ink: AppColors.successInk,
    isProtected: true,
    description:
        'Menghidupkan dosing pupuk A secara manual dapat mempengaruhi kadar '
        'nutrisi tanaman. Pastikan takaran sudah tepat.',
  ),
  RelaySpec(
    index: 1,
    name: 'Dosing Pupuk B',
    shortName: 'Pupuk B',
    icon: Icons.vaccines_rounded,
    accent: AppColors.info,
    ink: AppColors.infoInk,
    isProtected: true,
    description:
        'Menghidupkan dosing pupuk B secara manual dapat mempengaruhi kadar '
        'nutrisi tanaman. Pastikan takaran sudah tepat.',
  ),
  RelaySpec(
    index: 2,
    name: 'pH Up',
    shortName: 'pH Up',
    icon: Icons.arrow_circle_up_rounded,
    accent: AppColors.accent,
    ink: AppColors.accentInk,
    isProtected: true,
    description:
        'Menaikkan pH secara manual dapat mengubah keasaman larutan. '
        'Gunakan hanya jika dibutuhkan.',
  ),
  RelaySpec(
    index: 3,
    name: 'pH Down',
    shortName: 'pH Down',
    icon: Icons.arrow_circle_down_rounded,
    accent: AppColors.tertiary,
    ink: AppColors.tertiary,
    isProtected: true,
    description:
        'Menurunkan pH secara manual dapat mengubah keasaman larutan. '
        'Gunakan hanya jika dibutuhkan.',
  ),
  RelaySpec(
    index: 4,
    name: 'Exhaust Blower',
    shortName: 'Blower',
    icon: Icons.air_rounded,
    accent: AppColors.warning,
    ink: AppColors.warningInk,
    isProtected: false,
    description: '',
  ),
  RelaySpec(
    index: 5,
    name: 'Pompa Irigasi',
    shortName: 'Irigasi',
    icon: Icons.water_drop_rounded,
    accent: AppColors.secondary,
    ink: AppColors.secondary,
    isProtected: false,
    description: '',
  ),
];
