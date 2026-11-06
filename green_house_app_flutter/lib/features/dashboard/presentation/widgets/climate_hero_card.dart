import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_motion.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';

/// Botanical climate hero — the first thing an operator reads on the dashboard.
///
/// Every reading is nullable on purpose: a missing sensor value renders `—`
/// instead of a fabricated `0.0`, and the status pill is driven by the real
/// [GreenhouseStatus] rather than a hardcoded "Optimal". All colours come from
/// [AppColors] plus white overlays, and all type from [AppTextStyles], so the
/// card carries no private palette or font sizes.
class ClimateHeroCard extends StatelessWidget {
  const ClimateHeroCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.updatedLabel,
  });

  /// Air temperature in °C, or `null` when the sensor reported nothing.
  final double? temperature;

  /// Relative humidity in %, or `null` when the sensor reported nothing.
  final double? humidity;

  /// Aggregate greenhouse health (`offline` wins over `attention`).
  final GreenhouseStatus status;

  /// Humanised age of the last successful reading, e.g. `8 dtk` or `2 mnt`.
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    // ponytail: static multi-layer DecoratedBox gloss; upgrade to BackdropFilter blur if live camera feed sits behind hero.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: AppRadius.radiusXl3,
        boxShadow: const [AppShadows.hero],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 0.95,
            colors: [
              AppColors.secondaryContainer.withValues(alpha: 0.30),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.80, 0.85),
              radius: 0.90,
              colors: [
                AppColors.primaryFixed.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusXl3,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.34),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(0.45, 0.75),
                colors: [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.08),
                ],
                stops: const [0.0, 0.38, 0.70, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.marginMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroHeader(status: status),
                  const SizedBox(height: AppSpacing.spaceLg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.thermostat_rounded,
                          label: 'Suhu Udara',
                          value: temperature?.toStringAsFixed(1) ?? '—',
                          unit: '°C',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceMd),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.water_drop_rounded,
                          label: 'Kelembapan',
                          value: humidity?.toStringAsFixed(0) ?? '—',
                          unit: '% RH',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  _HeroFooter(updatedLabel: updatedLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + name + status pill.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.status});

  final GreenhouseStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: AppColors.logoRingGradient,
            borderRadius: AppRadius.radiusLg,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusDefault,
            child: ColoredBox(
              color: AppColors.onPrimary,
              child: Image.asset(
                'assets/images/greenhouse_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.eco, size: 22, color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // scaleDown keeps "Greenhouse 01" on one line at 1.3x instead of
              // breaking mid-word ("Greenhou / se 01").
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Greenhouse 01',
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              Text(
                'Mikroklimat',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        _StatusPill(status: status),
      ],
    );
  }
}

/// Dot + label pill. The whole pill is one Semantics node so screen readers
/// announce "Status greenhouse: …" instead of a bare adjective.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final GreenhouseStatus status;

  String get _label => switch (status) {
    GreenhouseStatus.optimal => 'Optimal',
    GreenhouseStatus.attention => 'Perlu perhatian',
    GreenhouseStatus.offline => 'Offline',
  };

  /// `optimal` keeps a white dot (healthy = neutral on the dark gradient),
  /// `attention` uses the warning fill, `offline` a dimmed dot.
  Color get _dotColor => switch (status) {
    GreenhouseStatus.optimal => AppColors.onPrimary,
    GreenhouseStatus.attention => AppColors.warning,
    GreenhouseStatus.offline => Colors.white.withValues(alpha: 0.54),
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Status greenhouse: $_label',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: AppRadius.radiusFull,
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _dotColor.withValues(alpha: 0.65),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted tile holding one reading.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;

  /// Pre-formatted reading, or `—` when the sensor reported nothing.
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(icon, size: 16, color: AppColors.onPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          // Wrap instead of Row: at large text scales the unit drops to its own
          // line rather than overflowing the tile.
          Wrap(
            spacing: 4,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _AnimatedValue(
                  value: value,
                  style: AppTextStyles.metricHero.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              Text(
                unit,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cross-fades a metric when its value changes (poll tick), and snaps instantly
/// when the platform asks for reduced motion.
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.reduceMotion(context)
          ? Duration.zero
          : AppMotion.base,
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: Text(
        value,
        key: ValueKey<String>(value),
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}

/// Threshold chips + data-freshness line.
class _HeroFooter extends StatelessWidget {
  const _HeroFooter({required this.updatedLabel});

  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    // `_formatAge` returns `tidak diketahui` before the first successful poll;
    // "Diperbarui tidak diketahui lalu" would read as broken Indonesian.
    final freshness = updatedLabel == 'tidak diketahui'
        ? 'Diperbarui: $updatedLabel'
        : 'Diperbarui $updatedLabel lalu';

    return Wrap(
      spacing: AppSpacing.spaceSm,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _ThresholdChip(label: 'Ideal 24–30°C'),
        const _ThresholdChip(label: 'RH 60–80%'),
        Text(
          freshness,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
      ],
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}
