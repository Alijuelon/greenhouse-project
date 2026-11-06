import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';

/// Bottom sheet for setting the irrigation pump timer duration.
///
/// Every entry of [_TimerBottomSheetState._durations] is rendered, each chip is
/// a >=48x48 tap target with an explicit semantics label, and the copy names the
/// actuator ("Pompa Irigasi") instead of a single greenhouse bed.
class TimerBottomSheet extends StatefulWidget {
  const TimerBottomSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TimerBottomSheet(),
    );
  }

  @override
  State<TimerBottomSheet> createState() => _TimerBottomSheetState();
}

class _TimerBottomSheetState extends State<TimerBottomSheet> {
  int _selectedIndex = 1; // Default: 10 menit

  static const List<int> _durations = [5, 10, 15, 30, 60]; // In minutes

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl3),
        ),
        boxShadow: const [AppShadows.bottomSheet],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.spaceMd),
              child: Container(
                width: AppSpacing.minTapTarget,
                height: AppSpacing.spaceXs,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: timer icon + title + close
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.accentInk,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.spaceSm),
                      Expanded(
                        child: Text(
                          'Set Timer Durasi Pompa',
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceXs),
                      Semantics(
                        button: true,
                        label: 'Tutup',
                        excludeSemantics: true,
                        child: IconButton(
                          key: const Key('timer-sheet-close'),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.minTapTarget,
                            minHeight: AppSpacing.minTapTarget,
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  // Description
                  Text(
                    'Pilih durasi siram otomatis untuk Pompa Irigasi hari ini.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceLg),
                  // Duration chips — wraps instead of a fixed Row so 320dp at
                  // 1.3x text scale never overflows.
                  Wrap(
                    spacing: AppSpacing.spaceSm,
                    runSpacing: AppSpacing.spaceSm,
                    children: List.generate(_durations.length, _buildChip),
                  ),
                  const SizedBox(height: AppSpacing.spaceXl),
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('timer-sheet-confirm'),
                      onPressed: () =>
                          Navigator.of(context).pop(_durations[_selectedIndex]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(
                          AppSpacing.minTapTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.spaceLg,
                          vertical: AppSpacing.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusXl,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 20),
                          const SizedBox(width: AppSpacing.spaceSm),
                          Flexible(
                            child: Text(
                              'Konfirmasi Jalankan Pompa',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(int index) {
    final minutes = _durations[index];
    final isSelected = index == _selectedIndex;
    final background = isSelected ? AppColors.accentSoft : AppColors.cardMuted;
    final foreground = isSelected
        ? AppColors.accentInk
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$minutes menit',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTapTarget,
          minHeight: AppSpacing.minTapTarget,
        ),
        child: Material(
          color: background,
          borderRadius: AppRadius.radiusXl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('timer-chip-$minutes'),
            onTap: () => setState(() => _selectedIndex = index),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceLg,
                vertical: AppSpacing.spaceSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$minutes',
                    style: AppTextStyles.labelLg.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  Text(
                    'menit',
                    style: AppTextStyles.caption.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
