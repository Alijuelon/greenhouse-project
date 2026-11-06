import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/services/ai_recommendation_service.dart';
import 'package:green_house_app/services/ai_pdf_service.dart';
import 'package:green_house_app/core/services/api_service.dart';
import 'package:green_house_app/features/analytics/presentation/pages/ai_performance_page.dart';
import 'package:intl/intl.dart';

class AIRecommendationPage extends StatefulWidget {
  const AIRecommendationPage({super.key});

  @override
  State<AIRecommendationPage> createState() => _AIRecommendationPageState();
}

class _AIRecommendationPageState extends State<AIRecommendationPage>
    with TickerProviderStateMixin {
  final _service = AIRecommendationService();

  LiveData? _live;
  DoseLogModel? _latestDose;
  List<DoseLogModel> _history = [];
  AIModeData? _aiMode;

  bool _isLoading = true;
  bool _isExporting = false;
  String _error = '';

  Map<String, dynamic>? _perfData; // AI performance data

  // History filter & sort state
  String? _filterSrc;    // null = semua, 'ai', 'expert', 'expert_shadow'
  bool _sortAsc = false; // false = terbaru dulu
  int _historyLimit = 10; // Jumlah riwayat yang ditampilkan

  Timer? _timer;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fetchAll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        _service.getLive(),
        _service.getDoseHistory(
          limit: _historyLimit,
          src: _filterSrc,
          sort: _sortAsc ? 'asc' : 'desc',
        ),
        _service.getAIMode(),
        ApiService.getAIPerformance(hours: 24),
      ]);
      if (!mounted) return;
      setState(() {
        _live = results[0] as LiveData;
        _history = results[1] as List<DoseLogModel>;
        _latestDose = _history.isNotEmpty
            ? (_sortAsc ? _history.last : _history.first)
            : null;
        _aiMode = results[2] as AIModeData;
        _perfData = results[3] as Map<String, dynamic>;
        _isLoading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_live == null) return;
    
    // Tampilkan dialog pilihan filter history
    final int? limit = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Data PDF'),
          content: const Text('Berapa riwayat data terakhir yang ingin dimasukkan ke PDF?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 10), child: const Text('10 Terakhir')),
            TextButton(onPressed: () => Navigator.pop(context, 20), child: const Text('20 Terakhir')),
            TextButton(onPressed: () => Navigator.pop(context, _history.length), child: const Text('Semua')),
          ],
        );
      },
    );

    if (limit == null) return; // Dibatalkan

    setState(() => _isExporting = true);
    try {
      final filteredHistory = _history.take(limit).toList();
      await AiPdfService.shareReport(
        live: _live!,
        latestDose: _latestDose,
        history: filteredHistory,
        mode: _aiMode ?? AIModeData(mode: 'off', phase: 1, ecSetpoint: 0),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteHistory() async {
    // Dialog dengan pilihan: semua, hanya filter aktif, sebelum tanggal
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat Dosis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih data yang ingin dihapus secara permanen:'),
            const SizedBox(height: 12),
            if (_filterSrc != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.filter_alt_outlined, color: Colors.orange),
                title: Text('Hanya data filter aktif (${_filterSrc ?? "semua"})'),
                onTap: () => Navigator.pop(context, 'filter'),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              title: const Text('Semua riwayat (permanen)'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      int deleted;
      if (choice == 'filter' && _filterSrc != null) {
        deleted = await _service.clearDoseHistory(src: _filterSrc);
      } else {
        deleted = await _service.clearDoseHistory();
      }
      await _fetchAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deleted data riwayat dosis berhasil dihapus'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus riwayat: $e'), backgroundColor: AppColors.danger),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _live == null) return _buildSkeleton();
    if (_error.isNotEmpty && _live == null) return _buildError();

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.spaceLg + 16),
            _buildHeroBanner(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildAIPerformanceBanner(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildSensorSection(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildDoseSection(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildHistorySection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ─── Hero Banner ───────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    final mode = _aiMode;
    final isOnline = _live?.isOnline ?? false;

    Color modeColor;
    IconData modeIcon;
    String modeLabel;
    switch (mode?.mode) {
      case 'auto':
        modeColor = AppColors.primary;
        modeIcon = Icons.auto_awesome;
        modeLabel = 'AI Otomatis';
        break;
      case 'shadow':
        modeColor = AppColors.secondary;
        modeIcon = Icons.psychology_outlined;
        modeLabel = 'Shadow Mode';
        break;
      default:
        modeColor = AppColors.textMuted;
        modeIcon = Icons.power_off_outlined;
        modeLabel = 'AI Nonaktif';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D47A1), // deep blue
            Color(0xFF1565C0), // blue
            Color(0xFF1B5E20), // green
            Color(0xFF2E7D32), // mid green
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(modeIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekomendasi AI',
                      style: AppTextStyles.headlineMd.copyWith(color: Colors.white),
                    ),
                    Text(
                      modeLabel,
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Info Icon
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                onPressed: _showAiModeInfo,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Informasi Mode AI',
              ),
              const SizedBox(width: 12),
              // Online indicator
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? Colors.greenAccent.withValues(alpha: _pulseAnim.value)
                        : Colors.red.shade300,
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.6 * _pulseAnim.value),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: AppTextStyles.labelSm.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _heroBadge('Fase ${mode?.phase ?? "—"}', Icons.eco_outlined),
              const SizedBox(width: 8),
              _heroBadge('EC ${mode?.ecSetpoint.toStringAsFixed(1) ?? "—"} mS/cm', Icons.electrical_services),
              const SizedBox(width: 8),
              _heroBadge('${_history.length} Log', Icons.history),
            ],
          ),
          const SizedBox(height: 16),
          // Export button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(_isExporting ? 'Membuat PDF...' : 'Export Laporan PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: modeColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAiModeInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Sistem Cerdas',
                  style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModeInfoItem(
              title: 'Expert Mode (Pakar)',
              description: 'Sistem mengikuti aturan/threshold manual. AI tidak mengintervensi.',
              icon: Icons.engineering_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            _buildModeInfoItem(
              title: 'AI Shadow (Bayangan)',
              description: 'Sistem berjalan manual, tetapi AI ikut menghitung prediksi secara sembunyi-sembunyi untuk membandingkan performa.',
              icon: Icons.psychology_outlined,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            _buildModeInfoItem(
              title: 'AI Auto (Otomatis)',
              description: 'Kendali penuh pada AI. AI menghitung dan langsung mengeksekusi pompa nutrisi secara real-time.',
              icon: Icons.auto_awesome_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeInfoItem({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLg.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIPerformanceBanner() {
    if (_perfData == null || _perfData!['error'] == 'no_data') {
      return const SizedBox.shrink();
    }

    final overall = (_perfData!['overall_score'] as num?)?.toDouble() ?? 0.0;
    final verdict = _perfData!['verdict'] as String? ?? 'poor';
    final rec = _perfData!['recommendation'] as String? ?? '';
    final nSamples = _perfData!['n_samples'] ?? 0;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (verdict) {
      case 'excellent':
        badgeColor = AppColors.success;
        badgeText = 'Sangat Baik';
        badgeIcon = Icons.verified_rounded;
        break;
      case 'good':
        badgeColor = Colors.blue;
        badgeText = 'Baik';
        badgeIcon = Icons.thumb_up_alt_rounded;
        break;
      case 'fair':
        badgeColor = AppColors.warning;
        badgeText = 'Cukup';
        badgeIcon = Icons.warning_rounded;
        break;
      default:
        badgeColor = AppColors.danger;
        badgeText = 'Buruk';
        badgeIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: badgeColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analisa Performa AI (24 Jam)',
                        style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text('$nSamples sampel dianalisa',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$badgeText ($overall)',
                      style: AppTextStyles.labelMd.copyWith(color: badgeColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rec.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec,
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIPerformancePage()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.query_stats_rounded, size: 16, color: badgeColor),
                  const SizedBox(width: 8),
                  Text(
                    'Lihat Analisa & Metrik Detail',
                    style: AppTextStyles.labelMd.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: badgeColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  // ─── Sensor Section ────────────────────────────────────────────────────────

  Widget _buildSensorSection() {
    final s = _live?.sensors ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Sensor Real-Time', Icons.sensors),
        const SizedBox(height: 10),
        _buildSensorGrid(s),
      ],
    );
  }

  Widget _buildSensorGrid(Map<String, dynamic> s) {
    final items = [
      _SensorItem('Suhu Udara', _fmtVal(s['air_suhu'], '°C'), Icons.thermostat, AppColors.danger,
          _statusColor('air_suhu', s['air_suhu']), _statusText('air_suhu', s['air_suhu'])),
      _SensorItem('Kelembapan Udara', _fmtVal(s['air_hum'], '%'), Icons.water_drop, AppColors.info,
          _statusColor('air_hum', s['air_hum']), _statusText('air_hum', s['air_hum'])),
      _SensorItem('pH', _fmtVal(s['ph'], 'pH'), Icons.science, AppColors.primary,
          _statusColor('ph', s['ph']), _statusText('ph', s['ph'])),
      _SensorItem('EC', _fmtVal(s['ec'], 'µS/cm'), Icons.electrical_services, AppColors.secondary,
          _statusColor('ec', s['ec']), _statusText('ec', s['ec'])),
      _SensorItem('Suhu Tanah', _fmtVal(s['tanah_suhu'], '°C'), Icons.terrain, AppColors.warning,
          _statusColor('tanah_suhu', s['tanah_suhu']), _statusText('tanah_suhu', s['tanah_suhu'])),
      _SensorItem('Kelembapan Tanah', _fmtVal(s['tanah_lembap'], '%'), Icons.grass, AppColors.primary,
          _statusColor('tanah_lembap', s['tanah_lembap']), _statusText('tanah_lembap', s['tanah_lembap'])),
      _SensorItem('N (Nitrogen)', _fmtVal(s['n'], 'mg/kg'), Icons.spa, AppColors.success, null, null),
      _SensorItem('P (Fosfor)', _fmtVal(s['p'], 'mg/kg'), Icons.psychology, AppColors.warning, null, null),
      _SensorItem('K (Kalium)', _fmtVal(s['k'], 'mg/kg'), Icons.eco, AppColors.primary, null, null),
    ];

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 3) {
      rows.add(Row(
        children: [
          for (int j = i; j < i + 3 && j < items.length; j++) ...[
            Expanded(child: _buildSensorCard(items[j])),
            if (j < i + 2 && j + 1 < items.length) const SizedBox(width: 8),
          ],
        ],
      ));
      if (i + 3 < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  Widget _buildSensorCard(_SensorItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.statusText != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (item.statusColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                item.statusText!,
                style: AppTextStyles.labelSm.copyWith(
                  color: item.statusColor ?? AppColors.primary,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Dose Section ──────────────────────────────────────────────────────────

  Widget _buildDoseSection() {
    final dose = _latestDose;
    if (dose == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Rekomendasi Dosis Terbaru', Icons.science),
          const SizedBox(height: 10),
          _emptyCard('Belum ada data dosis dari server.'),
        ],
      );
    }

    final mode = _aiMode?.mode ?? 'off';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Rekomendasi Dosis Terbaru', Icons.science),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${dose.id} · ${dose.srcLabel}',
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                                .format(dose.timestamp.toLocal()),
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Fase ${dose.phase}',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dosis Dieksekusi',
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _buildDoseGrid(dose.ml, AppColors.primary, Icons.colorize),
                    if (dose.hasAiPrediction && mode != 'off') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(
                                'Prediksi AI Murni',
                                style: AppTextStyles.labelSm.copyWith(color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 8),
                      _buildAiMlRow(dose),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoseGrid(Map<String, double> ml, Color color, IconData icon) {
    final keys = ['A', 'B', 'PH_UP', 'PH_DOWN'];
    final labels = ['Pupuk A', 'Pupuk B', 'pH Up', 'pH Down'];
    final icons = [Icons.colorize, Icons.vaccines, Icons.arrow_upward, Icons.arrow_downward];
    final colors = [AppColors.primary, AppColors.secondary, AppColors.warning, AppColors.danger];

    return Row(
      children: List.generate(keys.length, (i) {
        final val = ml[keys[i]] ?? 0.0;
        final isActive = val > 0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < keys.length - 1 ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isActive ? colors[i].withValues(alpha: 0.08) : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? colors[i].withValues(alpha: 0.3) : AppColors.surfaceBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(icons[i], color: isActive ? colors[i] : AppColors.textMuted, size: 18),
                  const SizedBox(height: 6),
                  Text(
                    val.toStringAsFixed(1),
                    style: AppTextStyles.headlineSm.copyWith(
                      color: isActive ? colors[i] : AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'ml',
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[i],
                    style: AppTextStyles.bodySm.copyWith(
                      color: isActive ? colors[i] : AppColors.textMuted,
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAiMlRow(DoseLogModel dose) {
    final labels = ['A', 'B', 'pH↑', 'pH↓'];
    return Row(
      children: List.generate(
        dose.aiMl!.length.clamp(0, 4),
        (i) {
          final val = dose.aiMl![i];
          final execVal = dose.ml[['A', 'B', 'PH_UP', 'PH_DOWN'][i]] ?? 0.0;
          final diff = val - execVal;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.infoSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      labels[i],
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.secondary),
                    ),
                    Text(
                      '${val.toStringAsFixed(1)} ml',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                      style: AppTextStyles.labelSm.copyWith(
                        color: diff.abs() < 0.5
                            ? AppColors.success
                            : diff > 0
                                ? AppColors.warning
                                : AppColors.danger,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── History Section ───────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    final srcLabels = {'ai': 'AI Auto', 'expert': 'Expert', 'expert_shadow': 'Shadow'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header row ────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.history, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Riwayat Dosis (${_history.length})',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface, fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Limit toggle
            PopupMenuButton<int>(
              initialValue: _historyLimit,
              onSelected: (value) {
                if (_historyLimit != value) {
                  setState(() => _historyLimit = value);
                  _fetchAll();
                }
              },
              tooltip: 'Jumlah Data',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_historyLimit',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.primary, fontSize: 11),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 10, child: Text('10 Data')),
                const PopupMenuItem(value: 20, child: Text('20 Data')),
                const PopupMenuItem(value: 50, child: Text('50 Data')),
                const PopupMenuItem(value: 100, child: Text('100 Data')),
              ],
            ),
            const SizedBox(width: 6),
            // Sort toggle
            InkWell(
              onTap: () {
                setState(() => _sortAsc = !_sortAsc);
                _fetchAll();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14, color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortAsc ? 'Terlama' : 'Terbaru',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.primary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: _history.isEmpty ? null : _deleteHistory,
              tooltip: 'Hapus Riwayat',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ─── Filter chips ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Semua', null, srcLabels),
              const SizedBox(width: 6),
              _buildFilterChip('AI Auto', 'ai', srcLabels),
              const SizedBox(width: 6),
              _buildFilterChip('Expert', 'expert', srcLabels),
              const SizedBox(width: 6),
              _buildFilterChip('Shadow', 'expert_shadow', srcLabels),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ─── List ──────────────────────────────────────────────────────
        if (_history.isEmpty)
          _emptyCard(_filterSrc != null
              ? 'Tidak ada data untuk filter "${srcLabels[_filterSrc] ?? _filterSrc}".'
              : 'Belum ada riwayat dosis.')
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildHistoryCard(_history[i]),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? value, Map<String, String> labels) {
    final isSelected = _filterSrc == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_filterSrc != value) {
          setState(() => _filterSrc = value);
          _fetchAll();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DoseLogModel dose) {
    final Color srcColor;
    switch (dose.src) {
      case 'ai':
        srcColor = AppColors.primary;
        break;
      case 'expert_shadow':
        srcColor = AppColors.secondary;
        break;
      default:
        srcColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: srcColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${dose.id}',
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurface),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: srcColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        dose.srcLabel,
                        style: AppTextStyles.labelSm.copyWith(color: srcColor, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM, HH:mm').format(dose.timestamp.toLocal()),
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'A:${(dose.ml['A'] ?? 0).toStringAsFixed(1)} B:${(dose.ml['B'] ?? 0).toStringAsFixed(1)}',
                style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
              ),
              if (dose.hasAiPrediction) ...[
                const SizedBox(height: 4),
                Text(
                  'AI A:${dose.aiMl![0].toStringAsFixed(1)} B:${dose.aiMl!.length > 1 ? dose.aiMl![1].toStringAsFixed(1) : "—"}',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.secondary, fontSize: 9),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Row(
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
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 36),
            const SizedBox(height: 8),
            Text(msg, style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceLg),
          _skeletonBox(height: 160, borderRadius: 20),
          const SizedBox(height: AppSpacing.spaceLg),
          _skeletonBox(height: 24, width: 160),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _skeletonBox(height: 80, borderRadius: 14)),
              const SizedBox(width: 8),
              Expanded(child: _skeletonBox(height: 80, borderRadius: 14)),
              const SizedBox(width: 8),
              Expanded(child: _skeletonBox(height: 80, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          _skeletonBox(height: 180, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _skeletonBox({double height = 60, double? width, double borderRadius = 12}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off, color: AppColors.danger, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Koneksi Gagal', style: AppTextStyles.headlineMd),
            const SizedBox(height: 8),
            Text(
              _error,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchAll();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _fmtVal(dynamic v, String unit) {
    if (v == null) return '—';
    final d = (v as num).toDouble();
    final str = d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
    return '$str $unit';
  }

  Color? _statusColor(String key, dynamic value) {
    if (value == null) return null;
    final v = (value as num).toDouble();
    switch (key) {
      case 'ph':
        return (v >= 5.5 && v <= 6.5) ? AppColors.success : AppColors.danger;
      case 'air_suhu':
        return (v >= 22 && v <= 35) ? AppColors.success : AppColors.warning;
      case 'air_hum':
        return (v >= 50 && v <= 80) ? AppColors.info : AppColors.warning;
      case 'tanah_suhu':
        return v < 30 ? AppColors.success : AppColors.danger;
      case 'tanah_lembap':
        return v > 40 ? AppColors.info : AppColors.warning;
      case 'ec':
        return v > 300 ? AppColors.success : AppColors.warning;
      default:
        return null;
    }
  }

  String? _statusText(String key, dynamic value) {
    if (value == null) return null;
    final v = (value as num).toDouble();
    switch (key) {
      case 'ph':
        return (v >= 5.5 && v <= 6.5) ? 'Normal' : 'Perlu Koreksi';
      case 'air_suhu':
        return (v >= 22 && v <= 35) ? 'Normal' : v < 22 ? 'Dingin' : 'Panas';
      case 'air_hum':
        return (v >= 50 && v <= 80) ? 'Optimal' : 'Di Luar Rentang';
      case 'tanah_suhu':
        return v < 30 ? 'Normal' : 'Panas';
      case 'tanah_lembap':
        return v > 40 ? 'Lembap' : 'Kering';
      case 'ec':
        return v > 300 ? 'Baik' : 'Rendah';
      default:
        return null;
    }
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────────

class _SensorItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? statusColor;
  final String? statusText;

  const _SensorItem(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.statusColor,
    this.statusText,
  );
}
