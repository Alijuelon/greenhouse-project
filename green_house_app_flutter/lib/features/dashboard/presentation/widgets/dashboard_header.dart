import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';

/// Dashboard eyebrow — greenhouse identity, status, data freshness and the
/// manual refresh affordance.
///
/// The health signal is passed in already resolved ([status] / [reasons]) so the
/// widget never re-derives it from a stale snapshot, and every colour/type/size
/// comes from the token layer: no private palette, no raw font sizes.
///
/// Both rows are built to survive a 360dp viewport at 1.3x text scale: the
/// eyebrow truncates instead of pushing the chip off-screen, and the freshness
/// line is a [Wrap] so the reasons drop to their own run instead of overflowing.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.snapshot,
    required this.status,
    required this.reasons,
    required this.updatedLabel,
    required this.onRefresh,
  });

  /// Snapshot the header describes. Used for the "Basi" chip's explanation —
  /// it distinguishes "never heard from the device" from "went quiet".
  final DashboardSnapshot snapshot;

  /// Aggregate health, resolved by the page via `resolveStatus`.
  final GreenhouseStatus status;

  /// Attention reasons from `attentionReasons(snapshot)`; at most two are shown.
  final List<String> reasons;

  /// Humanised age of the last successful reading, e.g. `8 dtk` or `2 mnt`.
  final String updatedLabel;

  /// Manual refresh (same callback as pull-to-refresh).
  final VoidCallback onRefresh;

  /// `_formatAge` returns `tidak diketahui` before the first successful poll;
  /// "Diperbarui tidak diketahui lalu" would read as broken Indonesian.
  String get _freshness => updatedLabel == 'tidak diketahui'
      ? 'Diperbarui: $updatedLabel'
      : 'Diperbarui $updatedLabel lalu';

  /// Why the data is marked stale — the honest difference between a device that
  /// never reported and one that stopped reporting.
  String get _staleTooltip => snapshot.lastSeen == null
      ? 'Belum pernah menerima data dari perangkat'
      : 'Data terakhir tidak lagi segar';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'GREENHOUSE 01',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            _StatusChip(status: status),
            const SizedBox(width: AppSpacing.spaceSm),
            Semantics(
              label: 'Muat ulang data',
              child: IconButton(
                onPressed: onRefresh,
                tooltip: 'Muat ulang data',
                icon: const Icon(Icons.refresh_rounded),
                iconSize: 22,
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.standard,
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTapTarget,
                  minHeight: AppSpacing.minTapTarget,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.spaceSm,
          runSpacing: AppSpacing.spaceXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _freshness,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
            if (reasons.isNotEmpty)
              Text(
                '· ${reasons.take(2).join(' · ')}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (status == GreenhouseStatus.offline)
              _StaleChip(tooltip: _staleTooltip),
          ],
        ),
      ],
    );
  }
}

/// Dot + label pill. The whole pill is one Semantics node so a screen reader
/// announces "Status greenhouse: …" instead of a bare adjective.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GreenhouseStatus status;

  String get _label => switch (status) {
    GreenhouseStatus.optimal => 'Optimal',
    GreenhouseStatus.attention => 'Perlu perhatian',
    GreenhouseStatus.offline => 'Offline',
  };

  /// Soft fill + matching `*Ink` label: the saturated fill tokens are 2–4:1 on
  /// white and therefore unfit for 11px text.
  Color get _background => switch (status) {
    GreenhouseStatus.optimal => AppColors.successSurface,
    GreenhouseStatus.attention => AppColors.warningSurface,
    GreenhouseStatus.offline => AppColors.surfaceContainerLow,
  };

  Color get _ink => switch (status) {
    GreenhouseStatus.optimal => AppColors.successInk,
    GreenhouseStatus.attention => AppColors.warningInk,
    GreenhouseStatus.offline => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Status greenhouse: $_label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: AppRadius.radiusFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: _ink, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                _label,
                maxLines: 1,
                softWrap: false,
                style: AppTextStyles.caption.copyWith(color: _ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Basi" marker shown when the status fell to offline (device silent/stale).
class _StaleChip extends StatelessWidget {
  const _StaleChip({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warningSurface,
          borderRadius: AppRadius.radiusFull,
        ),
        child: Text(
          'Basi',
          style: AppTextStyles.caption.copyWith(color: AppColors.warningInk),
        ),
      ),
    );
  }
}
