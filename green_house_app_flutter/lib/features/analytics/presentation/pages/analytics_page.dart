import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:green_house_app/core/services/api_service.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _selectedMetric = 0; // 0=Suhu, 1=Kelembapan, 2=NPK, 3=pH
  int _selectedRange = 0; // 0=24j, 1=7h, 2=30h, 3=Kustom
  
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  bool _isLoading = true;
  List<FlSpot> _chartSpots = [];
  String _errorMessage = '';
  
  double _kpiAvg = 0.0;
  double _kpiMax = 0.0;
  double _kpiMin = 0.0;
  
  List<dynamic> _activityLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    String metric = 'air_suhu';
    if (_selectedMetric == 1) {
      metric = 'air_hum';
    } else if (_selectedMetric == 2) {
      metric = 'n';
    } else if (_selectedMetric == 3) {
      metric = 'ph';
    }
    
    int hours = 24;
    if (_selectedRange == 1) {
      hours = 168;
    } else if (_selectedRange == 2) {
      hours = 720;
    }
    
    try {
      String? startStr;
      String? endStr;
      if (_selectedRange == 3 && _customStartDate != null && _customEndDate != null) {
        startStr = _customStartDate!.toIso8601String();
        endStr = _customEndDate!.toIso8601String();
      }
      
      final data = await ApiService.getAnalyticsChart(
        metric, hours,
        startDate: startStr,
        endDate: endStr,
      );
      final rawData = List<dynamic>.from(data['data'] ?? []);
      final kpi = Map<String, dynamic>.from(data['kpi'] ?? {});
      
      final logsData = await ApiService.getActivityLogs(limit: 4);
      
      List<FlSpot> spots = [];
      for (int i = 0; i < rawData.length; i++) {
         double yVal = (rawData[i]['value'] as num).toDouble();
         spots.add(FlSpot(i.toDouble(), yVal));
      }
      
      if (mounted) {
        setState(() {
          _chartSpots = spots.isNotEmpty ? spots : const [FlSpot(0, 0)];
          _kpiAvg = (kpi['avg'] as num?)?.toDouble() ?? 0.0;
          _kpiMax = (kpi['max'] as num?)?.toDouble() ?? 0.0;
          _kpiMin = (kpi['min'] as num?)?.toDouble() ?? 0.0;
          _activityLogs = logsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportReport() async {
    String? startStr;
    String? endStr;
    if (_selectedRange == 3 &&
        _customStartDate != null &&
        _customEndDate != null) {
      startStr = _customStartDate!.toIso8601String();
      endStr = _customEndDate!.toIso8601String();
    }
    final url = Uri.parse(
      ApiService.getExportUrl(startDate: startStr, endDate: endStr),
    );
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka url ekspor')),
      );
    }
  }

  String get _metricName => switch (_selectedMetric) {
    1 => 'Kelembapan',
    2 => 'Nitrogen',
    3 => 'Tingkat pH',
    _ => 'Suhu Udara',
  };

  String get _metricUnit => switch (_selectedMetric) {
    1 => '%',
    2 => 'mg/L',
    3 => 'pH',
    _ => '°C',
  };

  IconData get _metricIcon => switch (_selectedMetric) {
    1 => Icons.water_drop_rounded,
    2 => Icons.spa_rounded,
    3 => Icons.science_rounded,
    _ => Icons.thermostat_rounded,
  };

  String get _rangeName => switch (_selectedRange) {
    1 => '7 Hari',
    2 => '30 Hari',
    3 => 'Kustom',
    _ => '24 Jam',
  };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchChartData,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.spaceLg + 12),
            _buildHeroBanner(),
            const SizedBox(height: AppSpacing.spaceLg),
            // Filter Row — Metric Dropdown + Time Range Dropdown
            _buildFilterRow(),
            const SizedBox(height: AppSpacing.spaceLg),
            // KPI Summary Cards (3-col)
            _buildKpiCards(),
            const SizedBox(height: AppSpacing.spaceLg),
            // Chart Card
            _buildChartCard(),
            const SizedBox(height: AppSpacing.spaceLg),
            // Activity Log Section
            _buildActivitySection(),
            const SizedBox(height: AppSpacing.spaceMd),
            // Export Action Bar
            _buildExportBar(),
            const SizedBox(height: AppSpacing.spaceLg + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
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
              AppColors.secondaryContainer.withValues(alpha: 0.28),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analitik Sensor',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Greenhouse 01 · Tren & Riwayat Telemetri',
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF69F0AE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Sync',
                            style: AppTextStyles.labelSm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _heroBadge(_metricName, _metricIcon),
                    const SizedBox(width: 8),
                    _heroBadge(_rangeName, Icons.schedule_rounded),
                    const SizedBox(width: 8),
                    _heroBadge(
                      '${_activityLogs.length} Log',
                      Icons.history_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBadge(String text, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                style: AppTextStyles.labelSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    // Metric dropdown options
    final metrics = [
      (0, Icons.thermostat_rounded, 'Suhu (°C)'),
      (1, Icons.water_drop_outlined, 'Kelembapan (%)'),
      (2, Icons.spa_rounded, 'Nitrogen (N)'),
      (3, Icons.water_rounded, 'Tingkat pH'),
    ];

    // Time range dropdown options
    final ranges = [
      (0, '24 Jam'),
      (1, '7 Hari'),
      (2, '30 Hari'),
    ];

    return Row(
      children: [
        // ── Metric Dropdown ──────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
                width: 1.2,
              ),
              boxShadow: const [AppShadows.cardSm],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMetric,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                selectedItemBuilder: (context) => metrics
                    .map(
                      (m) => Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              m.$2,
                              color: AppColors.accentInk,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              m.$3,
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
                items: metrics
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.$1,
                        child: Row(
                          children: [
                            Icon(
                              m.$2,
                              color: _selectedMetric == m.$1
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              m.$3,
                              style: AppTextStyles.labelMd.copyWith(
                                color: _selectedMetric == m.$1
                                    ? AppColors.primary
                                    : AppColors.onSurface,
                                fontWeight: _selectedMetric == m.$1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedMetric) {
                    setState(() => _selectedMetric = val);
                    _fetchChartData();
                  }
                },
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Time Range Dropdown ──────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder, width: 1.2),
            boxShadow: const [AppShadows.cardSm],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedRange == 3 ? null : _selectedRange,
              hint: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Kustom',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              selectedItemBuilder: (context) => ranges
                  .map(
                    (r) => Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            r.$2,
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
              items: [
                ...ranges.map(
                  (r) => DropdownMenuItem(
                    value: r.$1,
                    child: Text(
                      r.$2,
                      style: AppTextStyles.labelMd.copyWith(
                        color: _selectedRange == r.$1
                            ? AppColors.primary
                            : AppColors.onSurface,
                        fontWeight: _selectedRange == r.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: -1, // sentinel for custom
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pilih Tanggal…',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (val) async {
                if (val == -1) {
                  // custom date range picker
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          onSurface: AppColors.onSurface,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (range != null) {
                    setState(() {
                      _selectedRange = 3;
                      _customStartDate = range.start;
                      _customEndDate = range.end;
                    });
                    _fetchChartData();
                  }
                } else if (val != null && val != _selectedRange) {
                  setState(() => _selectedRange = val);
                  _fetchChartData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCards() {
    final unit = _metricUnit;

    return Row(
      children: [
        _kpiCard(
          icon: Icons.analytics_outlined,
          iconSurface: AppColors.successSurface,
          iconColor: AppColors.successInk,
          label: 'Rata-rata',
          value: _kpiAvg.toStringAsFixed(1),
          unit: unit,
          chipLabel: 'Optimal',
          chipSurface: AppColors.successSurface,
          chipInk: AppColors.successInk,
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        _kpiCard(
          icon: Icons.trending_up_rounded,
          iconSurface: AppColors.warningSurface,
          iconColor: AppColors.warningInk,
          label: 'Tertinggi',
          value: _kpiMax.toStringAsFixed(1),
          unit: unit,
          chipLabel: 'Maksimum',
          chipSurface: AppColors.warningSurface,
          chipInk: AppColors.warningInk,
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        _kpiCard(
          icon: Icons.trending_down_rounded,
          iconSurface: AppColors.infoSurface,
          iconColor: AppColors.infoInk,
          label: 'Terendah',
          value: _kpiMin.toStringAsFixed(1),
          unit: unit,
          chipLabel: 'Minimum',
          chipSurface: AppColors.infoSurface,
          chipInk: AppColors.infoInk,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconSurface,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String chipLabel,
    required Color chipSurface,
    required Color chipInk,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: const [AppShadows.cardSm],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: iconSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.metricMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipSurface,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Text(
                chipLabel,
                style: AppTextStyles.caption.copyWith(
                  color: chipInk,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final metricName = _metricName;
    final metricUnit = _metricUnit;
    final rangeName = _rangeName;

    double upperLimit = 30.0;
    double lowerLimit = 24.0;
    String upperLabel = 'Batas Maks (30°C)';
    String lowerLabel = 'Batas Min (24°C)';

    if (_selectedMetric == 1) {
      upperLimit = 80.0;
      lowerLimit = 50.0;
      upperLabel = 'Batas Maks (80%)';
      lowerLabel = 'Batas Min (50%)';
    } else if (_selectedMetric == 2) {
      upperLimit = 150.0;
      lowerLimit = 50.0;
      upperLabel = 'Batas Maks (150 mg/L)';
      lowerLabel = 'Batas Min (50 mg/L)';
    } else if (_selectedMetric == 3) {
      upperLimit = 6.8;
      lowerLimit = 5.5;
      upperLabel = 'Batas Maks (6.8 pH)';
      lowerLabel = 'Batas Min (5.5 pH)';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: const [AppShadows.cardSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_metricIcon, color: AppColors.accentInk, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tren Fluktuasi $metricName',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Rentang waktu $rangeName · satuan $metricUnit',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      metricUnit,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.successInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          // fl_chart Line Chart
          SizedBox(
            height: 184,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      'Gagal memuat grafik',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: _chartSpots.isEmpty
                          ? 0
                          : _chartSpots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a < b ? a : b) -
                                5,
                      maxY: _chartSpots.isEmpty
                          ? 100
                          : _chartSpots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a > b ? a : b) +
                                5,
                      minX: _chartSpots.isEmpty ? 0 : _chartSpots.first.x,
                      maxX: _chartSpots.isEmpty ? 23 : _chartSpots.last.x,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.surfaceBorder,
                          strokeWidth: 1,
                          dashArray: [3, 4],
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          bottom: BorderSide(
                            color: AppColors.surfaceBorder,
                            width: 1,
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 4,
                            getTitlesWidget: (value, _) {
                              final hour = value.toInt();
                              final text =
                                  '${hour.toString().padLeft(2, '0')}:00';
                              final isPrimary = hour == 14;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  text,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: isPrimary
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    fontWeight: isPrimary
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: upperLimit,
                            color: AppColors.warningInk.withValues(alpha: 0.55),
                            strokeWidth: 1.2,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 2,
                              ),
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.warningInk,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              labelResolver: (_) => upperLabel,
                            ),
                          ),
                          HorizontalLine(
                            y: lowerLimit,
                            color: AppColors.infoInk.withValues(alpha: 0.55),
                            strokeWidth: 1.2,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 2,
                              ),
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.infoInk,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              labelResolver: (_) => lowerLabel,
                            ),
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartSpots.isNotEmpty
                              ? _chartSpots
                              : const [FlSpot(0, 0)],
                          isCurved: true,
                          curveSmoothness: 0.35,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1565C0),
                              AppColors.primary,
                              Color(0xFF2E7D32),
                            ],
                          ),
                          barWidth: 3.0,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              if (spot.x == 14) {
                                return FlDotCirclePainter(
                                  radius: 4.5,
                                  color: AppColors.primary,
                                  strokeColor: Colors.white,
                                  strokeWidth: 2,
                                );
                              }
                              if (spot.x == 12) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: AppColors.danger,
                                );
                              }
                              if (spot.x == 8) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: const Color(0xFF1565C0),
                                );
                              }
                              return FlDotCirclePainter(
                                radius: 0,
                                color: Colors.transparent,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF1565C0).withValues(alpha: 0.22),
                                AppColors.primary.withValues(alpha: 0.12),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.surface,
                          tooltipBorder: const BorderSide(
                            color: AppColors.surfaceBorder,
                            width: 1,
                          ),
                          tooltipRoundedRadius: 10,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(1)} $metricUnit\n${spot.x.toInt().toString().padLeft(2, '0')}:00',
                                AppTextStyles.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.successInk,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Rentang ideal $metricName berada pada ',
                        ),
                        TextSpan(
                          text: '$lowerLimit–$upperLimit $metricUnit',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.successInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' untuk periode $rangeName.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Riwayat Aktivitas',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Text(
                '${_activityLogs.length} aksi',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accentInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        // Timeline card
        Container(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: const [AppShadows.cardSm],
          ),
          child: _activityLogs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Tidak ada aktivitas tercatat.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_activityLogs.length, (index) {
                    final log = _activityLogs[index];
                    final isLast = index == _activityLogs.length - 1;

                    // Simple parse timestamp
                    String time = '';
                    try {
                      DateTime dt = DateTime.parse(log['timestamp']).toLocal();
                      time =
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    } catch (_) {}

                    return _timelineItem(
                      icon: Icons.bolt_rounded,
                      iconBg: AppColors.accentSoft,
                      iconColor: AppColors.accentInk,
                      time: time,
                      badge: log['event_type'] ?? 'Log',
                      badgeBg: AppColors.infoSurface,
                      badgeColor: AppColors.infoInk,
                      title: log['description'] ?? '',
                      subtitle: log['details'] ?? '',
                      showLine: !isLast,
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String time,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required bool showLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + line
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.surfaceBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          badge,
                          style: AppTextStyles.labelSm.copyWith(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: const [AppShadows.cardSm],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.accentInk,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Telemetri Lengkap',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Format CSV, XLSX, dan PDF Analitik',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _exportReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              'Unduh CSV',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
