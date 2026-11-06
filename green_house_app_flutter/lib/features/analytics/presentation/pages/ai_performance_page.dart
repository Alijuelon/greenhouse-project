import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:green_house_app/core/services/api_service.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_shadows.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';

class AIPerformancePage extends StatefulWidget {
  const AIPerformancePage({super.key});

  @override
  State<AIPerformancePage> createState() => _AIPerformancePageState();
}

class _AIPerformancePageState extends State<AIPerformancePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _perfData;
  List<dynamic> _history = [];
  int _selectedWindow = 0; // 0=24h, 1=48h, 2=7d

  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnim;

  int get _windowHours => [24, 48, 168][_selectedWindow];

  @override
  void initState() {
    super.initState();
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutCubic),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getAIPerformance(hours: _windowHours),
        ApiService.getAIPerformanceHistory(limit: 10),
      ]);

      final perf = results[0] as Map<String, dynamic>;
      final history = results[1] as List<dynamic>;

      if (!mounted) return;

      if (perf.containsKey('error') && perf['error'] == 'no_data') {
        setState(() {
          _perfData = null;
          _history = history;
          _isLoading = false;
        });
        return;
      }

      final score = (perf['overall_score'] as num?)?.toDouble() ?? 0;
      _scoreAnim = Tween<double>(begin: 0, end: score).animate(
        CurvedAnimation(
            parent: _scoreAnimController, curve: Curves.easeOutCubic),
      );
      _scoreAnimController.forward(from: 0);

      setState(() {
        _perfData = perf;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _computeAndSave() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.computeAIPerformance(hours: _windowHours);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Analisa performa berhasil disimpan'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Analisa Performa AI',
            style: AppTextStyles.headlineMd
                .copyWith(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.margin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.spaceLg),
                        _buildWindowSelector(),
                        const SizedBox(height: AppSpacing.spaceLg),
                        if (_perfData == null)
                          _buildNoData()
                        else ...[
                          _buildScoreCard(),
                          const SizedBox(height: AppSpacing.spaceLg),
                          _buildHeadStatsGrid(),
                          const SizedBox(height: AppSpacing.spaceLg),
                          _buildRecommendationCard(),
                          const SizedBox(height: AppSpacing.spaceLg),
                        ],
                        _buildHistorySection(),
                        const SizedBox(height: AppSpacing.spaceLg + 24),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: (_perfData != null && !_isLoading)
          ? FloatingActionButton.extended(
              onPressed: _computeAndSave,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Simpan Analisa'),
            )
          : null,
    );
  }

  // ── Window Selector ──────────────────────────────────────────
  Widget _buildWindowSelector() {
    final windows = ['24 Jam', '48 Jam', '7 Hari'];
    return Row(
      children: List.generate(windows.length, (i) {
        final selected = _selectedWindow == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (_selectedWindow != i) {
                setState(() => _selectedWindow = i);
                _fetchData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: i < 2 ? AppSpacing.spaceSm : 0),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceBorder,
                ),
                boxShadow: selected ? [AppShadows.cardMd] : [AppShadows.cardSm],
              ),
              alignment: Alignment.center,
              child: Text(
                windows[i],
                style: AppTextStyles.labelLg.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── No Data ──────────────────────────────────────────────────
  Widget _buildNoData() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space2xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.radiusXl,
        boxShadow: const [AppShadows.cardSm],
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'Belum Ada Data Shadow',
            style: AppTextStyles.headlineSm
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Text(
            'Aktifkan mode Shadow pada AI agar sistem merekam prediksi AI bersamaan dengan dosis expert. Data shadow diperlukan untuk menghitung performa model.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Error View ───────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.spaceMd),
            Text(_errorMessage ?? 'Terjadi kesalahan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.spaceLg),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Score Card (Hero) ────────────────────────────────────────
  Widget _buildScoreCard() {
    final score = (_perfData?['overall_score'] as num?)?.toDouble() ?? 0;
    final verdict = _perfData?['verdict'] ?? 'unknown';
    final nSamples = _perfData?['n_samples'] ?? 0;
    final windowHours = _perfData?['window_hours'] ?? 24;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D631B), Color(0xFF1E822D), Color(0xFF3DA54A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusXl,
        boxShadow: const [AppShadows.cardMd],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: AppSpacing.spaceSm),
              Text(
                'Skor Keseluruhan',
                style: AppTextStyles.labelLg
                    .copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Text(
                  '$nSamples sampel · ${windowHours}h',
                  style: AppTextStyles.labelSm
                      .copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          // Circular gauge
          SizedBox(
            width: 160,
            height: 160,
            child: AnimatedBuilder(
              animation: _scoreAnim,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScoreGaugePainter(
                    score: _scoreAnim.value,
                    maxScore: 100,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _scoreAnim.value.toStringAsFixed(1),
                          style: AppTextStyles.displayData.copyWith(
                            color: Colors.white,
                            fontSize: 40,
                          ),
                        ),
                        Text(
                          '/ 100',
                          style: AppTextStyles.labelSm
                              .copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          // Verdict badge
          _buildVerdictBadge(verdict, score),
        ],
      ),
    );
  }

  Widget _buildVerdictBadge(String verdict, double score) {
    final config = _verdictConfig(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: config.borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.textColor, size: 18),
          const SizedBox(width: AppSpacing.spaceSm),
          Text(
            config.label,
            style: AppTextStyles.labelLg.copyWith(color: config.textColor),
          ),
        ],
      ),
    );
  }

  // ── Per-Head Stats Grid ──────────────────────────────────────
  Widget _buildHeadStatsGrid() {
    final stats =
        (_perfData?['stats'] as Map<String, dynamic>?) ?? {};
    final heads = ['A', 'B', 'PH_UP', 'PH_DOWN'];
    final headLabels = {
      'A': 'Nutrisi A',
      'B': 'Nutrisi B',
      'PH_UP': 'pH Up',
      'PH_DOWN': 'pH Down',
    };
    final headIcons = {
      'A': Icons.science_rounded,
      'B': Icons.science_outlined,
      'PH_UP': Icons.arrow_upward_rounded,
      'PH_DOWN': Icons.arrow_downward_rounded,
    };
    final headColors = {
      'A': const Color(0xFF2E7D32),
      'B': const Color(0xFF00639A),
      'PH_UP': const Color(0xFFFFA000),
      'PH_DOWN': const Color(0xFF7B1FA2),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performa Per Head',
            style: AppTextStyles.headlineSm
                .copyWith(color: AppColors.onSurface)),
        const SizedBox(height: AppSpacing.spaceMd),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.spaceMd,
          crossAxisSpacing: AppSpacing.spaceMd,
          childAspectRatio: 0.95,
          children: heads.map((h) {
            final stat = (stats[h] as Map<String, dynamic>?) ?? {};
            final headScore = (stat['score'] as num?)?.toDouble() ?? 0;
            final mae = (stat['mae'] as num?)?.toDouble() ?? 0;
            final rmse = (stat['rmse'] as num?)?.toDouble() ?? 0;
            final color = headColors[h]!;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.radiusXl,
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: const [AppShadows.cardSm],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.radiusLg,
                        ),
                        child: Icon(headIcons[h], size: 18, color: color),
                      ),
                      const SizedBox(width: AppSpacing.spaceSm),
                      Expanded(
                        child: Text(
                          headLabels[h] ?? h,
                          style: AppTextStyles.labelLg
                              .copyWith(color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  // Score
                  Text(
                    headScore.toStringAsFixed(1),
                    style: AppTextStyles.headlineLg.copyWith(
                      color: _scoreColor(headScore),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXs),
                  // Progress bar
                  ClipRRect(
                    borderRadius: AppRadius.radiusFull,
                    child: LinearProgressIndicator(
                      value: (headScore / 100).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor:
                          AlwaysStoppedAnimation(_scoreColor(headScore)),
                    ),
                  ),
                  const Spacer(),
                  // MAE & RMSE
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat('MAE', '${mae.toStringAsFixed(1)} mL'),
                      ),
                      const SizedBox(width: AppSpacing.spaceXs),
                      Expanded(
                        child:
                            _buildMiniStat('RMSE', '${rmse.toStringAsFixed(1)} mL'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.textMuted, fontSize: 10)),
        Text(value,
            style: AppTextStyles.labelMd
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Recommendation Card ──────────────────────────────────────
  Widget _buildRecommendationCard() {
    final rec = _perfData?['recommendation'] ?? '';
    final verdict = _perfData?['verdict'] ?? 'unknown';
    final config = _verdictConfig(verdict);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: config.surfaceColor,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: config.borderColor.withValues(alpha: 0.4)),
        boxShadow: const [AppShadows.cardSm],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: config.textColor, size: 22),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rekomendasi',
                    style: AppTextStyles.labelLg
                        .copyWith(color: config.textColor)),
                const SizedBox(height: AppSpacing.spaceXs),
                Text(rec,
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── History Section ──────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Riwayat Analisa',
            style: AppTextStyles.headlineSm
                .copyWith(color: AppColors.onSurface)),
        const SizedBox(height: AppSpacing.spaceMd),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.spaceXl),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusXl,
              boxShadow: const [AppShadows.cardSm],
            ),
            child: Text(
              'Belum ada riwayat analisa tersimpan.\nTekan "Simpan Analisa" untuk menyimpan.',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          ...List.generate(_history.length, (i) {
            final item = _history[i] as Map<String, dynamic>;
            final score =
                (item['overall_score'] as num?)?.toDouble() ?? 0;
            final verdict = item['verdict'] ?? 'unknown';
            final nSamples = item['n_samples'] ?? 0;
            final windowH = item['window_hours'] ?? 24;
            final ts = item['timestamp'] ?? '';
            final config = _verdictConfig(verdict);

            return Container(
              margin: EdgeInsets.only(
                  bottom: i < _history.length - 1 ? AppSpacing.spaceSm : 0),
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.radiusXl,
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: const [AppShadows.cardSm],
              ),
              child: Row(
                children: [
                  // Score circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: config.bgColor,
                      border: Border.all(color: config.borderColor, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      score.toStringAsFixed(0),
                      style: AppTextStyles.labelLg
                          .copyWith(color: config.textColor),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: config.bgColor,
                                borderRadius: AppRadius.radiusFull,
                              ),
                              child: Text(
                                config.label,
                                style: AppTextStyles.labelSm
                                    .copyWith(color: config.textColor),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.spaceSm),
                            Text(
                              '$nSamples sampel · ${windowH}h',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space2xs),
                        Text(
                          _formatTimestamp(ts),
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Color _scoreColor(double score) {
    if (score >= 85) return const Color(0xFF2E7D32);
    if (score >= 70) return const Color(0xFF00639A);
    if (score >= 50) return const Color(0xFFFFA000);
    return const Color(0xFFD32F2F);
  }

  _VerdictConfig _verdictConfig(String verdict) {
    switch (verdict) {
      case 'excellent':
        return _VerdictConfig(
          label: 'Excellent',
          icon: Icons.emoji_events_rounded,
          textColor: const Color(0xFF1B5E20),
          bgColor: const Color(0xFFE8F5E9),
          surfaceColor: const Color(0xFFF1F8E9),
          borderColor: const Color(0xFF66BB6A),
        );
      case 'good':
        return _VerdictConfig(
          label: 'Good',
          icon: Icons.thumb_up_rounded,
          textColor: const Color(0xFF01579B),
          bgColor: const Color(0xFFE1F5FE),
          surfaceColor: const Color(0xFFE3F2FD),
          borderColor: const Color(0xFF42A5F5),
        );
      case 'fair':
        return _VerdictConfig(
          label: 'Fair',
          icon: Icons.warning_amber_rounded,
          textColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFFFF8E1),
          surfaceColor: const Color(0xFFFFF3E0),
          borderColor: const Color(0xFFFFB74D),
        );
      case 'poor':
        return _VerdictConfig(
          label: 'Poor',
          icon: Icons.error_outline_rounded,
          textColor: const Color(0xFFB71C1C),
          bgColor: const Color(0xFFFFEBEE),
          surfaceColor: const Color(0xFFFFCDD2),
          borderColor: const Color(0xFFEF5350),
        );
      default:
        return _VerdictConfig(
          label: 'Unknown',
          icon: Icons.help_outline,
          textColor: AppColors.textSecondary,
          bgColor: AppColors.surfaceContainerLow,
          surfaceColor: AppColors.surfaceContainerLow,
          borderColor: AppColors.outline,
        );
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} menit lalu';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours} jam lalu';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays} hari lalu';
      }
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ── Score Gauge Custom Painter ─────────────────────────────────
class _ScoreGaugePainter extends CustomPainter {
  final double score;
  final double maxScore;

  _ScoreGaugePainter({required this.score, required this.maxScore});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = 2.3;  // ~132°
    const sweepTotal = 4.58; // ~262°

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Score arc
    final fraction = (score / maxScore).clamp(0.0, 1.0);
    final sweepScore = sweepTotal * fraction;

    final scoreColor = _getColor(score);
    final scorePaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepScore,
        colors: [
          scoreColor.withValues(alpha: 0.6),
          scoreColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepScore,
      false,
      scorePaint,
    );

    // Glow dot at end
    if (fraction > 0.01) {
      final endAngle = startAngle + sweepScore;
      final dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawCircle(
          dotCenter,
          8,
          Paint()
            ..color = scoreColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(
          dotCenter,
          5,
          Paint()..color = Colors.white);
    }
  }

  Color _getColor(double score) {
    if (score >= 85) return const Color(0xFF66BB6A);
    if (score >= 70) return const Color(0xFF42A5F5);
    if (score >= 50) return const Color(0xFFFFB74D);
    return const Color(0xFFEF5350);
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter old) =>
      old.score != score;
}

// ── Verdict Config ─────────────────────────────────────────────
class _VerdictConfig {
  final String label;
  final IconData icon;
  final Color textColor;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;

  const _VerdictConfig({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
  });
}
