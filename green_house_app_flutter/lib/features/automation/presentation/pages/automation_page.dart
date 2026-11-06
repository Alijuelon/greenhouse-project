import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/core/services/api_service.dart';
import 'package:green_house_app/services/ai_recommendation_service.dart';

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage>
    with SingleTickerProviderStateMixin {
  String _aiMode = 'auto';
  bool get _isAiActive => _aiMode == 'auto' || _aiMode == 'shadow';
  bool _isLoading = false;
  bool _isSaving = false;
  late AnimationController _pulseController;

  final _aiService = AIRecommendationService();
  LiveData? _live;

  // AI dosing control state
  bool get _isDosingAuto => _aiMode == "auto";
  Map<String, double> _aiDoseRecommendation = {
    'A': 0,
    'B': 0,
    'PH_UP': 0,
    'PH_DOWN': 0,
  };
  final Map<String, bool> _headRunning = {
    'A': false,
    'B': false,
    'PH_UP': false,
    'PH_DOWN': false,
  };
  bool _isFetchingDose = false;
  String? _doseError;

  // Manual threshold controllers
  final _ecLowController = TextEditingController(text: '800');
  final _ecHighController = TextEditingController(text: '2000');
  final _phLowController = TextEditingController(text: '5.5');
  final _phHighController = TextEditingController(text: '7.5');
  final _suhuMaxController = TextEditingController(text: '32');

  // Duration controllers (seconds)
  final _ecLowDurationController = TextEditingController(text: '30');
  final _ecHighDurationController = TextEditingController(text: '30');
  final _phLowDurationController = TextEditingController(text: '15');
  final _phHighDurationController = TextEditingController(text: '15');
  final _suhuDurationController = TextEditingController(text: '60');

  // Existing rule IDs from backend (null = not yet created)
  int? _ruleIdDosingUp;
  int? _ruleIdDosingDown;
  int? _ruleIdPhUp;
  int? _ruleIdPhDown;
  int? _ruleIdBlower;

  // Track whether rules have been saved at least once
  bool _rulesSaved = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadExistingRules();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ecLowController.dispose();
    _ecHighController.dispose();
    _phLowController.dispose();
    _phHighController.dispose();
    _suhuMaxController.dispose();
    _ecLowDurationController.dispose();
    _ecHighDurationController.dispose();
    _phLowDurationController.dispose();
    _phHighDurationController.dispose();
    _suhuDurationController.dispose();
    super.dispose();
  }

  /// Load existing manual rules from backend and populate the form fields
  Future<void> _loadExistingRules() async {
    setState(() => _isLoading = true);

    // Mode tersimpan di server adalah sumber kebenaran (persist antar restart).
    var modeLoaded = false;
    try {
      final aiModeData = await _aiService.getAIMode();
      _aiMode = aiModeData.mode;
      modeLoaded = true;
    } catch (_) {}

    var manualRuleActive = false;
    try {
      final rules = await ApiService.getAutomationRules();
      for (final rule in rules) {
        final name = rule['name'] as String? ?? '';
        switch (name) {
          case 'Manual: Dosing Up (EC Low)':
            _ruleIdDosingUp = rule['id'] as int;
            _ecLowController.text = (rule['threshold'] as num).toString();
            _ecLowDurationController.text = (rule['duration'] as num)
                .toString();
            _rulesSaved = true;
            if (rule['is_active'] == true) manualRuleActive = true;
          case 'Manual: Dosing Down (EC High)':
            _ruleIdDosingDown = rule['id'] as int;
            _ecHighController.text = (rule['threshold'] as num).toString();
            _ecHighDurationController.text = (rule['duration'] as num)
                .toString();
          case 'Manual: pH Up':
            _ruleIdPhUp = rule['id'] as int;
            _phLowController.text = (rule['threshold'] as num).toString();
            _phLowDurationController.text = (rule['duration'] as num)
                .toString();
          case 'Manual: pH Down':
            _ruleIdPhDown = rule['id'] as int;
            _phHighController.text = (rule['threshold'] as num).toString();
            _phHighDurationController.text = (rule['duration'] as num)
                .toString();
          case 'Manual: Suhu Blower':
            _ruleIdBlower = rule['id'] as int;
            _suhuMaxController.text = (rule['threshold'] as num).toString();
            _suhuDurationController.text = (rule['duration'] as num).toString();
        }
      }
    } catch (_) {
      // Silently fail; user can still create rules manually
    }

    // Fallback: bila server tidak menjawab, simpulkan mode dari status aturan.
    if (!modeLoaded) {
      _aiMode = manualRuleActive ? 'off' : 'manual';
    }

    // Fetch live data for AI display
    try {
      _live = await _aiService.getLive();
    } catch (_) {}

    // Fetch latest AI recommendation
    await _fetchLatestAiDose();

    if (mounted) setState(() => _isLoading = false);
  }

  /// Ambil rekomendasi dosis AI terbaru dari model
  Future<void> _fetchLatestAiDose() async {
    setState(() {
      _isFetchingDose = true;
      _doseError = null;
    });
    try {
      final dose = await _aiService.getLatestAiDose();
      if (mounted) {
        setState(() {
          _aiDoseRecommendation = {
            'A': (dose['A'] as num?)?.toDouble() ?? 0.0,
            'B': (dose['B'] as num?)?.toDouble() ?? 0.0,
            'PH_UP': (dose['PH_UP'] as num?)?.toDouble() ?? 0.0,
            'PH_DOWN': (dose['PH_DOWN'] as num?)?.toDouble() ?? 0.0,
          };
        });
      }
    } catch (e) {
      if (mounted) setState(() => _doseError = e.toString());
    } finally {
      if (mounted) setState(() => _isFetchingDose = false);
    }
  }

  /// Eksekusi satu head dosing secara manual
  Future<void> _runDosingHead(String head) async {
    if (_headRunning[head] == true) return;
    setState(() => _headRunning[head] = true);

    // Hitung durasi dari volume rekomendasi AI (10 detik per ml, min 5, max 60)
    final ml = _aiDoseRecommendation[head] ?? 0;
    final durationSec = (ml > 0) ? (ml * 2).round().clamp(5, 60) : 10;

    try {
      await _aiService.runDosingHead(head: head, durationSec: durationSec);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dosing $head dijalankan selama ${durationSec}s (${ml.toStringAsFixed(1)} ml)',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Simulate duration then re-enable
      final durationSec2 = (ml > 0) ? (ml * 2).round().clamp(5, 60) : 10;
      await Future.delayed(Duration(seconds: durationSec2));
      if (mounted) setState(() => _headRunning[head] = false);
    }
  }

  /// Save or update all 5 manual threshold rules to the backend
  Future<void> _saveManualRules() async {
    setState(() => _isSaving = true);

    final manualRules = [
      {
        'id': _ruleIdDosingUp,
        'name': 'Manual: Dosing Up (EC Low)',
        'sensor_target': 'ec',
        'operator': '<',
        'threshold': double.tryParse(_ecLowController.text) ?? 800,
        'duration': int.tryParse(_ecLowDurationController.text) ?? 30,
        'actuator_target': 0, // Relay 0 – Dosing Pupuk A (Sinkron ESP32)
        'is_active': !_isAiActive,
      },
      {
        'id': _ruleIdDosingDown,
        'name': 'Manual: Dosing Down (EC High)',
        'sensor_target': 'ec',
        'operator': '>',
        'threshold': double.tryParse(_ecHighController.text) ?? 2000,
        'duration': int.tryParse(_ecHighDurationController.text) ?? 30,
        'actuator_target': 1, // Relay 1 – Dosing Pupuk B (Sinkron ESP32)
        'is_active': !_isAiActive,
      },
      {
        'id': _ruleIdPhUp,
        'name': 'Manual: pH Up',
        'sensor_target': 'ph',
        'operator': '<',
        'threshold': double.tryParse(_phLowController.text) ?? 5.5,
        'duration': int.tryParse(_phLowDurationController.text) ?? 15,
        'actuator_target': 2, // Relay 2 – pH Up (Sinkron ESP32)
        'is_active': !_isAiActive,
      },
      {
        'id': _ruleIdPhDown,
        'name': 'Manual: pH Down',
        'sensor_target': 'ph',
        'operator': '>',
        'threshold': double.tryParse(_phHighController.text) ?? 7.5,
        'duration': int.tryParse(_phHighDurationController.text) ?? 15,
        'actuator_target': 3, // Relay 3 – pH Down (Sinkron ESP32)
        'is_active': !_isAiActive,
      },
      {
        'id': _ruleIdBlower,
        'name': 'Manual: Suhu Blower',
        'sensor_target': 'air_suhu',
        'operator': '>',
        'threshold': double.tryParse(_suhuMaxController.text) ?? 32,
        'duration': int.tryParse(_suhuDurationController.text) ?? 60,
        'actuator_target': 4, // Relay 4 – Exhaust Blower (Sinkron ESP32)
        'is_active': !_isAiActive,
      },
    ];

    bool allSuccess = true;

    for (int i = 0; i < manualRules.length; i++) {
      final rule = manualRules[i];
      final existingId = rule['id'] as int?;

      try {
        if (existingId != null) {
          // Update existing rule
          final success = await ApiService.updateAutomationRule(
            existingId,
            rule,
          );
          if (!success) allSuccess = false;
        } else {
          // Create new rule – we need to get the ID back
          // The API returns { "success": true, "id": <new_id> }
          // Since addAutomationRule returns bool, we re-fetch rules after
          final success = await ApiService.addAutomationRule(rule);
          if (!success) allSuccess = false;
        }
      } catch (_) {
        allSuccess = false;
      }
    }

    // Re-fetch rules to get any newly created IDs
    await _loadExistingRules();

    if (mounted) {
      setState(() {
        _isSaving = false;
        _rulesSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allSuccess
                ? 'Pengaturan manual berhasil disimpan'
                : 'Sebagian pengaturan gagal disimpan',
          ),
          backgroundColor: allSuccess ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Metadata tiap mode operasi: label, ikon, warna aksen, dan penjelasan
  /// singkat yang ditampilkan pada dialog konfirmasi.
  static const Map<String, Map<String, dynamic>> _modeMeta = {
    'auto': {
      'label': 'AI Auto',
      'icon': Icons.auto_awesome,
      'desc':
          'Sistem AI mengambil alih penuh. Dosis pupuk & aktuator dijalankan '
          'otomatis berdasarkan pembacaan sensor real-time tanpa perlu input manual.',
    },
    'shadow': {
      'label': 'AI Rekomendasi',
      'icon': Icons.lightbulb_outline,
      'desc':
          'Mode bayangan. AI hanya memberi rekomendasi dosis sebagai saran, '
          'aktuator TIDAK dijalankan otomatis — keputusan tetap di tangan Anda.',
    },
    'manual': {
      'label': 'Manual Kontrol',
      'icon': Icons.touch_app,
      'desc':
          'Anda mengendalikan relay/aktuator langsung dari aplikasi. '
          'AI dan aturan threshold tidak akan menggerakkan pompa.',
    },
    'off': {
      'label': 'Expert Rule',
      'icon': Icons.tune,
      'desc':
          'Anda membuat aturan sendiri: "jika sensor melewati batas tertentu, '
          'nyalakan aktuator selama durasi tertentu". Aturan berjalan otomatis '
          'saat kondisinya terpenuhi, tanpa campur tangan AI.',
    },
  };

  /// Dialog konfirmasi sebelum berpindah mode operasi.
  Future<void> _handleModeTap(String mode) async {
    if (mode == _aiMode) {
      final current = _modeMeta[mode]!['label'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.onSurface,
          content: Text(
            'Mode $current sudah aktif.',
            style: AppTextStyles.bodySm.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    final meta = _modeMeta[mode]!;
    final label = meta['label'] as String;
    final desc = meta['desc'] as String;
    final icon = meta['icon'] as IconData;
    final accent = _modeAccent(mode);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktifkan mode ini?',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          label,
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  desc,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurface,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.save_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pilihan ini disimpan permanen di server dan diterapkan '
                      'ke ESP32, jadi tetap aktif walau aplikasi ditutup.',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        'Batal',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Aktifkan',
                        style: AppTextStyles.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final ok = await _setMode(mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.primary : AppColors.danger,
        content: Text(
          ok
              ? 'Mode $label aktif & tersimpan permanen.'
              : 'Gagal menyimpan mode $label. Periksa koneksi server.',
        ),
      ),
    );
  }

  Color _modeAccent(String mode) {
    switch (mode) {
      case 'auto':
        return AppColors.primary;
      case 'shadow':
        return AppColors.info;
      case 'manual':
        return AppColors.secondary;
      default:
        return AppColors.warning;
    }
  }

  /// Toggle AI mode and deactivate/activate manual rules.
  /// Mengembalikan `true` bila mode berhasil dipersist ke server.
  Future<bool> _setMode(String newMode) async {
    setState(() => _aiMode = newMode);
    var persisted = false;
    try {
      await _aiService.setAIMode(newMode);
      persisted = true;
    } catch (_) {}
    final ruleIds = [
      _ruleIdDosingUp,
      _ruleIdDosingDown,
      _ruleIdPhUp,
      _ruleIdPhDown,
      _ruleIdBlower,
    ];
    for (final id in ruleIds) {
      if (id != null) {
        try {
          await ApiService.toggleRuleActive(id, newMode == 'off');
        } catch (_) {}
      }
    }
    return persisted;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceLg + 16),
          _buildHeader(),
          const SizedBox(height: AppSpacing.spaceLg),
          if (_isAiActive) ...[
            _buildDosingGrid(),
          ] else if (_aiMode == 'manual') ...[
            _buildPureManualSection(),
          ] else ...[
            _buildManualThresholdSection(),
          ],
          const SizedBox(height: AppSpacing.spaceLg + 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final activeMeta = _modeMeta[_aiMode] ?? _modeMeta['auto']!;
    final activeLabel = activeMeta['label'] as String;
    final activeIcon = activeMeta['icon'] as IconData;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: const Alignment(0.45, 0.75),
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.05),
                Colors.transparent,
                Colors.white.withValues(alpha: 0.07),
              ],
              stops: const [0.0, 0.38, 0.70, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top header row ───────────────────────────
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
                      child: Icon(activeIcon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Operasi',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pilih kendali otomasi greenhouse',
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Active mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) => Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF69F0AE).withValues(
                                  alpha: 0.55 + 0.45 * _pulseController.value,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activeLabel,
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

                // ── Baris 1 ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        'AI Auto',
                        'Otomatis penuh',
                        'auto',
                        Icons.auto_awesome,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeCard(
                        'AI Rekomendasi',
                        'Saran dosis AI',
                        'shadow',
                        Icons.lightbulb_outline,
                        AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Baris 2 ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        'Manual Kontrol',
                        'Saklar langsung',
                        'manual',
                        Icons.touch_app,
                        AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModeCard(
                        'Expert Rule',
                        'Batas threshold',
                        'off',
                        Icons.tune,
                        AppColors.warning,
                      ),
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

  Widget _buildModeCard(
    String label,
    String subtitle,
    String mode,
    IconData icon,
    Color accentColor,
  ) {
    final isSelected = _aiMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleModeTap(mode),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.26),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? accentColor : Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelMd.copyWith(
                        color: isSelected ? AppColors.onSurface : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected
                            ? AppColors.textSecondary
                            : Colors.white.withValues(alpha: 0.76),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  MANUAL THRESHOLD SECTION (shown when AI is OFF)
  // ───────────────────────────────────────────────────────────

  Widget _buildManualThresholdSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: EC Dosing
        _buildSectionTitle(
          'Dosing Nutrisi (EC)',
          Icons.science_outlined,
          AppColors.secondary,
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        _buildThresholdCard(
          title: 'Dosing Up — Pupuk A',
          subtitle: 'Aktif saat EC di bawah threshold',
          icon: Icons.colorize,
          color: AppColors.secondary,
          relayLabel: 'Relay 1',
          thresholdController: _ecLowController,
          durationController: _ecLowDurationController,
          unit: 'µS/cm',
          operatorLabel: 'EC <',
          isActive: _ruleIdDosingUp != null,
        ),
        const SizedBox(height: 12),
        _buildThresholdCard(
          title: 'Dosing Down — Pupuk B / Air',
          subtitle: 'Aktif saat EC di atas threshold',
          icon: Icons.vaccines,
          color: AppColors.info,
          relayLabel: 'Relay 2',
          thresholdController: _ecHighController,
          durationController: _ecHighDurationController,
          unit: 'µS/cm',
          operatorLabel: 'EC >',
          isActive: _ruleIdDosingDown != null,
        ),

        const SizedBox(height: AppSpacing.spaceLg + 8),

        // Section: pH
        _buildSectionTitle(
          'Koreksi pH Tanah',
          Icons.water_drop_outlined,
          AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        _buildThresholdCard(
          title: 'pH Up — Basa Kuat',
          subtitle: 'Aktif saat pH terlalu asam (rendah)',
          icon: Icons.arrow_upward,
          color: AppColors.warning,
          relayLabel: 'Relay 4',
          thresholdController: _phLowController,
          durationController: _phLowDurationController,
          unit: 'pH',
          operatorLabel: 'pH <',
          isActive: _ruleIdPhUp != null,
        ),
        const SizedBox(height: 12),
        _buildThresholdCard(
          title: 'pH Down — Asam Kuat',
          subtitle: 'Aktif saat pH terlalu basa (tinggi)',
          icon: Icons.arrow_downward,
          color: AppColors.danger,
          relayLabel: 'Relay 5',
          thresholdController: _phHighController,
          durationController: _phHighDurationController,
          unit: 'pH',
          operatorLabel: 'pH >',
          isActive: _ruleIdPhDown != null,
        ),

        const SizedBox(height: AppSpacing.spaceLg + 8),

        // Section: Suhu Blower
        _buildSectionTitle(
          'Kontrol Suhu Blower',
          Icons.thermostat_outlined,
          AppColors.danger,
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        _buildThresholdCard(
          title: 'Exhaust Blower',
          subtitle: 'Aktif saat suhu udara terlalu panas',
          icon: Icons.mode_fan_off_outlined,
          color: AppColors.danger,
          relayLabel: 'Relay 3',
          thresholdController: _suhuMaxController,
          durationController: _suhuDurationController,
          unit: '°C',
          operatorLabel: 'Suhu >',
          isActive: _ruleIdBlower != null,
        ),

        const SizedBox(height: AppSpacing.spaceXl),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveManualRules,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _rulesSaved
                            ? 'Perbarui Pengaturan Manual'
                            : 'Simpan Pengaturan Manual',
                        style: AppTextStyles.labelLg.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        if (_rulesSaved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Threshold manual aktif. Aktuator akan otomatis menyesuaikan berdasarkan nilai sensor.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }

  Widget _buildThresholdCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String relayLabel,
    required TextEditingController thresholdController,
    required TextEditingController durationController,
    required String unit,
    required String operatorLabel,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.4)
              : AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  relayLabel,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Input row: Threshold + Duration
          Row(
            children: [
              // Threshold input
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operatorLabel,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: thresholdController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          suffixText: unit,
                          suffixStyle: AppTextStyles.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Duration input
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Durasi',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          suffixText: 'detik',
                          suffixStyle: AppTextStyles.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  AI DOSING CONTROL PANEL (with auto / manual)
  // ───────────────────────────────────────────────────────────

  Widget _buildDosingGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section title (plain, no card) ─────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.science_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rekomendasi Dosing AI',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    _isDosingAuto
                        ? 'Eksekusi otomatis setiap rekomendasi AI masuk'
                        : 'Klik Run untuk eksekusi per-head secara manual',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Refresh recommendation button
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _isFetchingDose ? null : _fetchLatestAiDose,
                icon: _isFetchingDose
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                tooltip: 'Refresh Rekomendasi',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),


        // ── Error state ────────────────────────────────────────
        if (_doseError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Model AI belum dimuat. Upload model terlebih dahulu.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),
        ],

        // ── Dosing head cards ─────────────────────────────────
        _buildDosingHeadCard(
          head: 'A',
          label: 'Nutrisi A',
          subtitle: 'Dosing Pupuk A — Relay 1',
          icon: Icons.science_rounded,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 10),
        _buildDosingHeadCard(
          head: 'B',
          label: 'Nutrisi B',
          subtitle: 'Dosing Pupuk B — Relay 2',
          icon: Icons.vaccines_rounded,
          color: const Color(0xFF0288D1),
        ),
        const SizedBox(height: 10),
        _buildDosingHeadCard(
          head: 'PH_UP',
          label: 'pH Up',
          subtitle: 'Koreksi Basa — Relay 4',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(height: 10),
        _buildDosingHeadCard(
          head: 'PH_DOWN',
          label: 'pH Down',
          subtitle: 'Koreksi Asam — Relay 5',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.danger,
        ),

        // ── Auto mode explanation ─────────────────────────────
        if (_isDosingAuto) ...[
          const SizedBox(height: AppSpacing.spaceMd),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mode Otomatis aktif: Setiap kali ESP32 mengirim data sensor, model AI menghitung dan ESP32 langsung mengeksekusi relay dosing secara real-time.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDosingHeadCard({
    required String head,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final ml = _aiDoseRecommendation[head] ?? 0.0;
    final durationSec = (ml > 0) ? (ml * 2).round().clamp(5, 60) : 10;
    final isRunning = _headRunning[head] == true;
    final hasRec = ml > 0;

    return InkWell(
      onTap: () => _showDosingInfo(head, label, subtitle, icon, color, ml, durationSec),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasRec
              ? color.withValues(alpha: 0.35)
              : AppColors.outlineVariant.withValues(alpha: 0.4),
          width: hasRec ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasRec
                ? color.withValues(alpha: 0.07)
                : const Color(0x05000000),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasRec
                  ? color.withValues(alpha: 0.12)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: hasRec ? color : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Label + ML info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasRec
                            ? color.withValues(alpha: 0.1)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasRec ? '${ml.toStringAsFixed(1)} ml' : '-- ml',
                        style: AppTextStyles.labelSm.copyWith(
                          color: hasRec ? color : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasRec) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${durationSec}s',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    if (_isDosingAuto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Auto',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Run button (manual mode only)
          if (!_isDosingAuto)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isRunning
                  ? Container(
                      key: const ValueKey('running'),
                      width: 72,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('run'),
                      onTap: hasRec
                          ? () {
                              HapticFeedback.mediumImpact();
                              _runDosingHead(head);
                            }
                          : null,
                      child: Container(
                        width: 72,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: hasRec
                              ? LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: hasRec ? null : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasRec
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: hasRec
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Run',
                              style: AppTextStyles.labelSm.copyWith(
                                color: hasRec
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            )
          else
            // Auto mode: show status indicator
            Container(
              width: 72,
              height: 40,
              decoration: BoxDecoration(
                color: isRunning
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRunning
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: hasRec ? AppColors.primary : AppColors.textMuted,
                    ),
            ),
        ],
      ),
    ),
  );
}

  void _showDosingInfo(
    String head,
    String label,
    String subtitle,
    IconData icon,
    Color color,
    double ml,
    int durationSec,
  ) {
    final s = _live?.sensors ?? {};
    final n = (s['n'] as num?)?.toDouble();
    final p = (s['p'] as num?)?.toDouble();
    final k = (s['k'] as num?)?.toDouble();
    final ph = (s['ph'] as num?)?.toDouble();
    final ec = (s['ec'] as num?)?.toDouble();

    String fmtSensor(double? v, String unit) =>
        v != null ? '${v.toStringAsFixed(1)} $unit' : '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail $label',
                            style: AppTextStyles.headlineSm,
                          ),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Kondisi Tanah Saat Ini ─────────────────────
                Row(
                  children: [
                    const Icon(Icons.grass, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Kondisi Tanah — Dasar Rekomendasi AI',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _soilChip('N (Nitrogen)', fmtSensor(n, 'mg/kg'), AppColors.success, Icons.spa_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: _soilChip('P (Fosfor)', fmtSensor(p, 'mg/kg'), AppColors.warning, Icons.psychology_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: _soilChip('K (Kalium)', fmtSensor(k, 'mg/kg'), AppColors.primary, Icons.eco_outlined)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _soilChip('pH Tanah', fmtSensor(ph, 'pH'), AppColors.info, Icons.science_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: _soilChip('EC', fmtSensor(ec, 'µS'), AppColors.secondary, Icons.electrical_services_outlined)),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox()), // placeholder agar rata
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Detail Dosing ──────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.water_drop, color: AppColors.info, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Rekomendasi Dosing',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Volume Dosing', ml > 0 ? '${ml.toStringAsFixed(1)} ml' : 'Tidak ada (0 ml)', Icons.water_drop_outlined, color),
                      const Divider(height: 24),
                      _infoRow('Durasi Pompa', ml > 0 ? '$durationSec detik' : '-', Icons.timer_outlined, AppColors.info),
                      const Divider(height: 24),
                      _infoRow('Relay Kontrol', subtitle.split('—').last.trim(), Icons.electrical_services_outlined, AppColors.secondary),
                      const Divider(height: 24),
                      _infoRow('Mode Eksekusi', _isDosingAuto ? 'Otomatis' : 'Manual (Tombol Run)', Icons.smart_toy_outlined, AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isDosingAuto)
                  Text(
                    '*Karena menggunakan mode AI Auto, sistem akan langsung mengeksekusi pompa ini segera setelah data prediksi terbaru masuk.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  )
                else
                  Text(
                    '*Karena menggunakan mode AI Rekomendasi (Shadow), Anda perlu menekan tombol "Run" pada card untuk mengeksekusi rekomendasi ini.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _soilChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.labelLg.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }


  Widget _infoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary)),
        ),
        Text(value, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  PURE MANUAL SECTION
  // ───────────────────────────────────────────────────────────
  Widget _buildPureManualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Kontrol Pompa Manual',
          Icons.touch_app_outlined,
          AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        _buildManualPumpCard(
          'Pompa A',
          'A',
          AppColors.secondary,
          Icons.colorize,
        ),
        const SizedBox(height: 12),
        _buildManualPumpCard('Pompa B', 'B', AppColors.info, Icons.vaccines),
        const SizedBox(height: 12),
        _buildManualPumpCard(
          'pH Up',
          'PH_UP',
          AppColors.warning,
          Icons.arrow_upward,
        ),
        const SizedBox(height: 12),
        _buildManualPumpCard(
          'pH Down',
          'PH_DOWN',
          AppColors.danger,
          Icons.arrow_downward,
        ),
        const SizedBox(height: 12),
        // Emergency Stop
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _sendManualPump('STOP', 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 28),
            label: const Text(
              'EMERGENCY STOP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualPumpCard(
    String title,
    String pumpId,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
                  style: AppTextStyles.labelLg.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kirim perintah injeksi manual',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showManualInputDialog(title, pumpId),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Injeksi'),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog(String title, String pumpId) {
    final tc = TextEditingController(text: '50');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Injeksi $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan volume (mL) untuk diinjeksikan secara manual:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tc,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Volume (mL)',
                border: OutlineInputBorder(),
                suffixText: 'mL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(tc.text) ?? 0;
              Navigator.pop(ctx);
              if (val > 0) {
                _sendManualPump(pumpId, val);
              }
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendManualPump(String pumpId, double ml) async {
    try {
      await ApiService.sendManualCommand(
        deviceId: 'esp32_greenhouse_01',
        pump: pumpId,
        ml: ml,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pumpId == 'STOP'
                  ? 'Perintah Stop Darurat dikirim'
                  : 'Perintah manual $ml mL untuk $pumpId terkirim.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim perintah: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
