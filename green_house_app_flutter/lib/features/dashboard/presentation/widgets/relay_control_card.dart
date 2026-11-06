import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_motion.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/relay_spec.dart';

/// One actuator tile: icon, name, honest state chips and a real [Switch].
///
/// The whole tile is the tap target (>= 48dp), so a gloved thumb cannot miss
/// it. Semantics are declared once, on the outer node, and the inner switch is
/// excluded so a screen reader announces a single toggle instead of a toggle
/// nested inside a button.
class RelayControlCard extends StatelessWidget {
  const RelayControlCard({
    super.key,
    required this.spec,
    required this.isOn,
    required this.isPending,
    required this.onToggle,
  });

  final RelaySpec spec;
  final bool isOn;

  /// A command is in flight; the switch is disabled and the tile says so.
  final bool isPending;

  final VoidCallback onToggle;

  /// Plain-language state used by both the chip row and the semantics label.
  String get _statusLabel {
    if (isOn) return 'Aktif';
    return spec.isProtected ? 'Terlindungi' : 'Siaga';
  }

  String get _semanticsLabel => isPending
      ? '${spec.name}, $_statusLabel, menunggu perangkat'
      : '${spec.name}, $_statusLabel';

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduceMotion(context);
    final surface = isOn ? AppColors.accentSoft : AppColors.card;
    final border = isOn ? AppColors.accent : AppColors.cardBorder;

    return Semantics(
      container: true,
      button: true,
      toggled: isOn,
      label: _semanticsLabel,
      onTap: onToggle,
      // The whole tile is one control: the icon, name, chips and the inner
      // switch must not be announced a second time as separate nodes.
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AppMotion.base,
          curve: AppMotion.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppRadius.radiusXl2,
            border: Border.all(color: border),
          ),
          // Transparency keeps the ink splash visible above the animated
          // surface instead of hiding it under an opaque child.
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggle,
              borderRadius: AppRadius.radiusXl2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTapTarget,
                    minHeight: AppSpacing.minTapTarget,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.14),
                              borderRadius: AppRadius.radiusLg,
                            ),
                            child: Icon(spec.icon, color: spec.ink, size: 20),
                          ),
                          const Spacer(),
                          Switch(
                            value: isOn,
                            onChanged: isPending ? null : (_) => onToggle(),
                            activeThumbColor: Colors.white,
                            activeTrackColor: spec.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Text(
                        spec.name,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (isOn)
                            _StatusChip(
                              label: 'Aktif',
                              background: AppColors.successSurface,
                              foreground: AppColors.successInk,
                            )
                          else if (spec.isProtected)
                            _StatusChip(
                              label: 'Terlindungi',
                              background: AppColors.warningSurface,
                              foreground: AppColors.warningInk,
                            )
                          else
                            _StatusChip(
                              label: 'Siaga',
                              background: AppColors.cardMuted,
                              foreground: AppColors.textSecondary,
                            ),
                          if (isPending)
                            _StatusChip(
                              label: 'Menunggu perangkat',
                              background: AppColors.infoSurface,
                              foreground: AppColors.infoInk,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.radiusFull,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: foreground),
      ),
    );
  }
}
