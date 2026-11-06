import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';

/// One glanceable card replacing the three 9–12px bento tiles: AI mode, how many
/// actuators are running, and the soil probe.
///
/// A [Wrap] — not a `Row` of three `Expanded` — so the three stats reflow onto
/// two or three runs at 360dp with 1.3x text instead of overflowing. Missing
/// readings render `—`, never `0.0`.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({
    super.key,
    required this.snapshot,
    required this.activeRelayCount,
  });

  final DashboardSnapshot snapshot;

  /// Relays currently commanded on (page-owned optimistic state).
  final int activeRelayCount;

  @override
  Widget build(BuildContext context) {
    final soilTemp = snapshot.soilTemp;
    final soilMoisture = snapshot.soilMoisture;

    final soilValue = soilTemp == null
        ? '—'
        : '${soilTemp.toStringAsFixed(1)}°C';
    final soilLabel = soilMoisture == null
        ? '—'
        : '${soilMoisture.toStringAsFixed(0)}% RH tanah';

    return Container(
      // Stretch to the page width: the parent column is start-aligned, so
      // without this the card would hug its content and shrink with the stats.
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.radiusXl2,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [AppShadows.cardXs],
      ),
      child: Wrap(
        spacing: AppSpacing.spaceLg,
        runSpacing: AppSpacing.spaceMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _InlineStat(
            icon: Icons.psychology_rounded,
            iconSurface: AppColors.infoSurface,
            iconColor: AppColors.infoInk,
            value: snapshot.aiMode.toUpperCase(),
            label: 'Mode AI',
            semanticsLabel: 'Mode AI ${snapshot.aiMode.toUpperCase()}',
          ),
          _InlineStat(
            icon: Icons.power_rounded,
            iconSurface: AppColors.successSurface,
            iconColor: AppColors.successInk,
            value: '$activeRelayCount / ${DashboardSnapshot.relayCount}',
            label: 'menyala',
            semanticsLabel:
                'Aktuator $activeRelayCount dari '
                '${DashboardSnapshot.relayCount} menyala',
          ),
          _InlineStat(
            icon: Icons.grass_rounded,
            iconSurface: AppColors.warningSurface,
            iconColor: AppColors.warningInk,
            value: soilValue,
            label: soilLabel,
            semanticsLabel: 'Tanah $soilValue $soilLabel',
          ),
        ],
      ),
    );
  }
}

/// Icon tile + value + label, one visual unit inside the strip.
class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.iconSurface,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });

  final IconData icon;
  final Color iconSurface;
  final Color iconColor;

  /// Pre-formatted reading, or `—` when the sensor reported nothing.
  final String value;
  final String label;

  /// Full sentence for screen readers — the visual parts are excluded so they
  /// are not read as three disconnected fragments.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: Semantics(
        container: true,
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconSurface,
                  borderRadius: AppRadius.radiusLg,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metricMd.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
