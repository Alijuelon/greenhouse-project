import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';

/// Nutrient and substrate readings from the 7-in-1 probe.
///
/// The card sits on a plain light surface ([AppColors.card]) — no photo
/// background, no dark overlay — so every glyph is drawn with a text-safe
/// token colour instead of white-on-image.
///
/// Every reading is nullable: a missing value renders `—` and a
/// "Tidak ada data" chip, never a fabricated `0` and never an alarm for a
/// reading the probe did not send.
class Npk7In1Card extends StatelessWidget {
  const Npk7In1Card({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  /// Agronomic targets behind the NPK progress bars (mg/kg).
  static const double _targetN = 150;
  static const double _targetP = 60;
  static const double _targetK = 220;

  @override
  Widget build(BuildContext context) {
    final hasReading =
        snapshot.n != null ||
        snapshot.p != null ||
        snapshot.k != null ||
        snapshot.ph != null ||
        snapshot.ec != null ||
        snapshot.soilTemp != null ||
        snapshot.soilMoisture != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.radiusXl3,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [AppShadows.cardXs],
      ),
      padding: const EdgeInsets.all(AppSpacing.marginMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(isLive: snapshot.isOnline, soilOk: snapshot.soilOk),
          const SizedBox(height: AppSpacing.spaceLg),
          if (!hasReading)
            const _NoSensorPanel()
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NpkTile(
                    letter: 'N',
                    label: 'Nitrogen',
                    value: snapshot.n,
                    target: _targetN,
                    badgeBackground: AppColors.successSurface,
                    badgeForeground: AppColors.successInk,
                    barColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: _NpkTile(
                    letter: 'P',
                    label: 'Fosfor',
                    value: snapshot.p,
                    target: _targetP,
                    badgeBackground: AppColors.warningSurface,
                    badgeForeground: AppColors.warningInk,
                    barColor: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: _NpkTile(
                    letter: 'K',
                    label: 'Kalium',
                    value: snapshot.k,
                    target: _targetK,
                    badgeBackground: AppColors.infoSurface,
                    badgeForeground: AppColors.infoInk,
                    barColor: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            _SecondaryGrid(snapshot: snapshot),
          ],
        ],
      ),
    );
  }
}

/// Title, freshness chip and the soil-fault chip.
class _Header extends StatelessWidget {
  const _Header({required this.isLive, required this.soilOk});

  /// `snapshot.isOnline` — the server's own freshness verdict.
  final bool isLive;

  final bool soilOk;

  @override
  Widget build(BuildContext context) {
    final label = isLive ? 'LIVE' : 'Basi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrisi & Substrat',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Sensor 7-in-1',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            Semantics(
              container: true,
              label: 'Status data nutrisi: $label',
              child: ExcludeSemantics(
                child: _Chip(
                  label: label,
                  background: isLive
                      ? AppColors.accentSoft
                      : AppColors.warningSurface,
                  foreground: isLive
                      ? AppColors.accentInk
                      : AppColors.warningInk,
                ),
              ),
            ),
          ],
        ),
        if (!soilOk) ...[
          const SizedBox(height: AppSpacing.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: _Chip(
              label: 'Tanah bermasalah',
              background: AppColors.warningSurface,
              foreground: AppColors.warningInk,
            ),
          ),
        ],
      ],
    );
  }
}

/// One nutrient tile: letter badge, reading, progress towards the target.
class _NpkTile extends StatelessWidget {
  const _NpkTile({
    required this.letter,
    required this.label,
    required this.value,
    required this.target,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.barColor,
  });

  final String letter;
  final String label;

  /// Reading in mg/kg, or `null` when the probe sent nothing.
  final double? value;

  /// Agronomic target in mg/kg.
  final double target;

  final Color badgeBackground;
  final Color badgeForeground;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final reading = value;
    // A missing reading fills 0% of the bar — never a fabricated fraction.
    final progress = reading == null ? 0.0 : (reading / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.radiusXl2,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: AppRadius.radiusLg,
            ),
            child: Text(
              letter,
              style: AppTextStyles.labelLg.copyWith(
                color: badgeForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          // Value and unit are stacked so all three tiles keep the same height
          // (and therefore the same bar baseline) at every text scale.
          Text(
            reading?.toStringAsFixed(0) ?? '—',
            maxLines: 1,
            style: AppTextStyles.metricMd.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'mg/kg',
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          _TargetBar(progress: progress, color: barColor),
          const SizedBox(height: AppSpacing.spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Target ${target.toInt()}',
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// pH / EC / soil temperature / soil moisture, 2 columns narrow, 4 wide.
class _SecondaryGrid extends StatelessWidget {
  const _SecondaryGrid({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 600 ? 4 : 2;
        const gap = AppSpacing.spaceMd;
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemWidth,
              child: _SecondaryTile(
                icon: Icons.science_outlined,
                label: 'pH',
                value: snapshot.ph?.toStringAsFixed(1) ?? '—',
                unit: null,
                chip: _phStyle(snapshot.ph),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SecondaryTile(
                icon: Icons.bolt_rounded,
                label: 'EC',
                value: snapshot.ec?.toStringAsFixed(0) ?? '—',
                unit: 'µS/cm',
                chip: _ecStyle(snapshot.ec),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SecondaryTile(
                icon: Icons.thermostat_rounded,
                label: 'Suhu Tanah',
                value: snapshot.soilTemp?.toStringAsFixed(1) ?? '—',
                unit: '°C',
                chip: _soilTempStyle(snapshot.soilTemp),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SecondaryTile(
                icon: Icons.water_drop_outlined,
                label: 'Kelembapan Tanah',
                value: snapshot.soilMoisture?.toStringAsFixed(0) ?? '—',
                unit: '%',
                chip: _soilMoistureStyle(snapshot.soilMoisture),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One secondary reading with its range verdict.
class _SecondaryTile extends StatelessWidget {
  const _SecondaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.chip,
  });

  final IconData icon;
  final String label;

  /// Pre-formatted reading, or `—` when the probe sent nothing.
  final String value;
  final String? unit;
  final _ChipStyle chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.radiusXl2,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.spaceXs + 2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceXs + 2),
          Wrap(
            spacing: 3,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                style: AppTextStyles.metricMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (unit != null)
                Text(
                  unit!,
                  maxLines: 1,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          _Chip(
            label: chip.label,
            background: chip.background,
            foreground: chip.foreground,
          ),
        ],
      ),
    );
  }
}

/// 4px track + filled fraction, both clipped to a pill.
class _TargetBar extends StatelessWidget {
  const _TargetBar({required this.progress, required this.color});

  /// Already clamped to 0..1; `0` when the reading is missing.
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: ClipRRect(
        borderRadius: AppRadius.radiusFull,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.cardMuted),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill label. Colour pairs come from [_ChipStyle] so a chip never mixes a
/// fill-only token with small text.
class _Chip extends StatelessWidget {
  const _Chip({
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: 3,
      ),
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

/// Shown when the payload carried none of the seven probe readings.
class _NoSensorPanel extends StatelessWidget {
  const _NoSensorPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLg,
        vertical: AppSpacing.spaceXl,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardMuted,
        borderRadius: AppRadius.radiusXl2,
      ),
      child: Column(
        children: [
          const Icon(Icons.sensors_off, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'Sensor 7-in-1 tidak terdeteksi',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'Periksa kabel probe dan daya sensor pada perangkat.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Background/foreground pair for a status chip.
class _ChipStyle {
  const _ChipStyle(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  /// No reading: muted, never an alarm.
  static const _ChipStyle noData = _ChipStyle(
    'Tidak ada data',
    AppColors.cardMuted,
    AppColors.textMuted,
  );

  static const _ChipStyle ideal = _ChipStyle(
    'Ideal',
    AppColors.successSurface,
    AppColors.successInk,
  );

  static const _ChipStyle low = _ChipStyle(
    'Rendah',
    AppColors.warningSurface,
    AppColors.warningInk,
  );

  static const _ChipStyle high = _ChipStyle(
    'Tinggi',
    AppColors.warningSurface,
    AppColors.warningInk,
  );

  static const _ChipStyle acidic = _ChipStyle(
    'Asam',
    AppColors.warningSurface,
    AppColors.warningInk,
  );

  static const _ChipStyle alkaline = _ChipStyle(
    'Basa',
    AppColors.warningSurface,
    AppColors.warningInk,
  );
}

/// Hydroponic pH window: 5.5–6.5.
_ChipStyle _phStyle(double? ph) {
  if (ph == null) return _ChipStyle.noData;
  if (ph < 5.5) return _ChipStyle.acidic;
  if (ph > 6.5) return _ChipStyle.alkaline;
  return _ChipStyle.ideal;
}

/// Nutrient solution conductivity: at least 300 µS/cm.
_ChipStyle _ecStyle(double? ec) {
  if (ec == null) return _ChipStyle.noData;
  if (ec < 300) return _ChipStyle.low;
  return _ChipStyle.ideal;
}

/// Root-zone temperature window: 20–30 °C. The plan does not pin a
/// soil-temperature band, so this mirrors the 24–30 °C air-temperature window
/// shifted one step lower: cooler substrate reads "Rendah", warmer "Tinggi".
_ChipStyle _soilTempStyle(double? soilTemp) {
  if (soilTemp == null) return _ChipStyle.noData;
  if (soilTemp < 20) return _ChipStyle.low;
  if (soilTemp > 30) return _ChipStyle.high;
  return _ChipStyle.ideal;
}

/// Substrate moisture: at least 40 %.
_ChipStyle _soilMoistureStyle(double? soilMoisture) {
  if (soilMoisture == null) return _ChipStyle.noData;
  if (soilMoisture < 40) return _ChipStyle.low;
  return _ChipStyle.ideal;
}
