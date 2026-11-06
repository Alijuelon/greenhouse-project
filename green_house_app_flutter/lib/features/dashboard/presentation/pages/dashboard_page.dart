import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:green_house_app/core/services/api_service.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';
import 'package:green_house_app/features/dashboard/domain/relay_spec.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/climate_hero_card.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/npk_7_in_1_card.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/relay_control_card.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/timer_bottom_sheet.dart';

/// Hard limit for a single dashboard request. A hanging server must degrade to
/// the "stale / error" path instead of freezing the skeleton forever.
const Duration _requestTimeout = Duration(seconds: 4);

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.isActive = true,
    this.fetcher = ApiService.getDashboardLive,
    this.pollInterval = const Duration(seconds: 5),
    this.clock,
  });

  /// Whether the dashboard is the visible tab. Polling only runs when active.
  final bool isActive;

  /// Injectable data source so widget tests never touch the network.
  final Future<Map<String, dynamic>> Function() fetcher;

  /// Poll cadence. `null` disables polling entirely (no timer is created).
  final Duration? pollInterval;

  /// Test seam for the "data X lalu" label. Defaults to [DateTime.now].
  @visibleForTesting
  final DateTime Function()? clock;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Last successful payload, kept across failures so old data stays readable.
  DashboardSnapshot? _snapshot;

  bool _isLoading = true;
  String? _error;
  DateTime? _lastSuccessAt;

  /// Guards against overlapping requests (poll tick while a manual retry runs).
  bool _isRefreshing = false;

  /// Relay indexes whose ON/OFF command is still in flight. Cards in this set
  /// show "Menunggu perangkat" and disable their switch.
  final Set<int> _pendingRelays = <int>{};

  /// Optimistic overlay on top of [DashboardSnapshot.targetRelays].
  List<bool> _relayStates = List<bool>.filled(
    DashboardSnapshot.relayCount,
    false,
  );

  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChanged,
    );
    _fetchData();
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pollInterval != widget.pollInterval) {
      // Re-arm with the new cadence instead of keeping the old period.
      _timer?.cancel();
      _timer = null;
    }
    if (!oldWidget.isActive && widget.isActive) {
      // Returning to the tab: refresh right away instead of waiting a tick.
      _fetchData();
    }
    _syncPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    super.dispose();
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// Single place that decides whether a periodic timer may exist.
  void _syncPolling() {
    final interval = widget.pollInterval;
    final shouldPoll =
        interval != null &&
        widget.isActive &&
        _lifecycleState == AppLifecycleState.resumed;

    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer ??= Timer.periodic(interval, (_) => _fetchData());
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    _lifecycleState = state;
    _syncPolling();
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final data = await widget.fetcher().timeout(_requestTimeout);
      if (!mounted) return;
      final snapshot = DashboardSnapshot.fromJson(data);
      setState(() {
        _snapshot = snapshot;
        _lastSuccessAt = _now();
        _error = null;
        _isLoading = false;
        _relayStates = List<bool>.of(snapshot.targetRelays);
      });
    } catch (error) {
      if (!mounted) return;
      // Keep _snapshot: the previous reading stays on screen behind a banner.
      setState(() {
        _error = _describeError(error);
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  String _describeError(Object error) {
    if (error is TimeoutException) {
      return 'Server tidak merespons dalam ${_requestTimeout.inSeconds} detik. '
          'Periksa koneksi lalu coba lagi.';
    }
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  Future<void> _toggleRelay(int index, bool currentState) async {
    if (ApiService.isHapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }

    // Optimistic UI update — reverted below when the server says no.
    setState(() {
      _relayStates = List<bool>.of(_relayStates)..[index] = !currentState;
      _pendingRelays.add(index);
    });

    try {
      final ok = await ApiService.toggleRelay(index, !currentState);
      if (!ok) {
        throw Exception('Perintah relay ditolak server');
      }
      if (!mounted) return;
      await _fetchData(); // Sync with the real device state.
      if (!mounted) return;
      setState(() => _pendingRelays.remove(index));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _relayStates = List<bool>.of(_relayStates)..[index] = currentState;
        _pendingRelays.remove(index);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_describeRelayError(error))));
    }
  }

  String _describeRelayError(Object error) {
    if (error is Exception) {
      final text = error.toString();
      const prefix = 'Exception: ';
      if (text.startsWith(prefix)) return text.substring(prefix.length);
    }
    return 'Gagal mengubah relay: $error';
  }

  /// Humanised age of [_lastSuccessAt], e.g. `2 mnt` or `35 dtk`.
  String _formatAge(DateTime? lastSuccessAt) {
    if (lastSuccessAt == null) return 'tidak diketahui';
    final age = _now().difference(lastSuccessAt);
    if (age.inMinutes < 1) return '${age.inSeconds} dtk';
    if (age.inHours < 1) return '${age.inMinutes} mnt';
    return '${age.inHours} jam';
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      key: const Key('dashboard-skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceLg + 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: AppRadius.radiusXl2,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          Container(
            height: 24,
            width: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: AppRadius.radiusLg,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm + 2),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: AppRadius.radiusXl,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gutterSm),
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: AppRadius.radiusXl,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shown only when there is nothing at all to display.
  Widget _buildColdErrorState(String message) {
    return Center(
      key: const Key('dashboard-cold-error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: AppSpacing.spaceLg),
            Text('Koneksi Gagal', style: AppTextStyles.headlineSm),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchData();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  /// Non-blocking warning above the (still readable) last known data.
  Widget _buildStaleBanner() {
    return Container(
      key: const Key('dashboard-stale-banner'),
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceMd,
        vertical: AppSpacing.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Text(
              'Gagal memperbarui • data ${_formatAge(_lastSuccessAt)} lalu',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface),
            ),
          ),
          TextButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    if (snapshot == null) {
      final error = _error;
      if (!_isLoading && error != null) return _buildColdErrorState(error);
      return _buildSkeletonLoader();
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.spaceLg + 12),
            if (_error != null) _buildStaleBanner(),
            // Climate Hero Card
            ClimateHeroCard(
              temperature: snapshot.airTemp,
              humidity: snapshot.airHum,
              status: resolveStatus(snapshot, now: _now()),
              updatedLabel: _formatAge(_lastSuccessAt),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            Npk7In1Card(snapshot: snapshot),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildRelayHeader(context),
            const SizedBox(height: AppSpacing.spaceSm + 2),
            _buildRelayGrid(),
            const SizedBox(height: AppSpacing.spaceLg + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayHeader(BuildContext context) {
    final activeCount = _relayStates.where((e) => e).length;

    // A `Wrap` (not a `Row`) so the title + chip and the "Atur Durasi" button
    // move onto separate runs at 360dp / 1.3x text instead of overflowing.
    // [LayoutBuilder] gives the wrap the full page width, which is what lets
    // `spaceBetween` actually push the button to the trailing edge on wide
    // surfaces (a loose `Wrap` would shrink to its content).
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: Wrap(
          spacing: AppSpacing.spaceMd,
          runSpacing: AppSpacing.spaceSm,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Kontrol Aktuator',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Text(
                    '$activeCount / 6 aktif',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentInk,
                    ),
                  ),
                ),
              ],
            ),
            Semantics(
              button: true,
              label: 'Atur durasi pompa irigasi',
              excludeSemantics: true,
              child: Material(
                color: AppColors.accentSoft,
                borderRadius: AppRadius.radiusXl,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('dashboard-atur-durasi'),
                  onTap: () async {
                    final durationMins = await TimerBottomSheet.show(context);
                    if (durationMins != null) {
                      try {
                        // Relay index 5 = Pompa Irigasi (Sinkron ESP32)
                        await ApiService.setRelayTimer(5, durationMins * 60);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Timer pompa irigasi diatur selama '
                                '$durationMins menit',
                              ),
                            ),
                          );
                        }
                        _fetchData();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal mengatur timer: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTapTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: AppColors.accentInk,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Atur Durasi',
                            style: AppTextStyles.labelLg.copyWith(
                              color: AppColors.accentInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRelayTap(int index, bool currentState) async {
    final spec = relaySpecs[index];

    // If turning OFF → always allow
    // If turning ON a free relay (Blower/Pompa) → allow directly
    if (currentState || !spec.isProtected) {
      _toggleRelay(index, currentState);
      return;
    }

    // Protected relay: show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl3),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + title
              Container(
                padding: const EdgeInsets.all(AppSpacing.spaceLg),
                decoration: BoxDecoration(
                  color: spec.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: spec.ink,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              Text(
                'Hidupkan Manual?',
                style: AppTextStyles.headlineSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                spec.name,
                style: AppTextStyles.labelMd.copyWith(
                  color: spec.ink,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.cardMuted,
                  borderRadius: AppRadius.radiusXl,
                  border: Border.all(
                    color: spec.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: spec.ink, size: 16),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Expanded(
                      child: Text(
                        spec.description,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg + AppSpacing.spaceXs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusXl,
                        ),
                        side: const BorderSide(
                          color: AppColors.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: AppSpacing.spaceSm + AppSpacing.space2xs,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        // `spec.ink` (not `accent`) so the white label keeps
                        // AA contrast on the fill.
                        backgroundColor: spec.ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.spaceMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusXl,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Ya, Hidupkan',
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

    if (confirmed == true) {
      _toggleRelay(index, currentState);
    }
  }

  Widget _buildRelayGrid() {
    // Responsive 2/3-column mosaic: `LayoutBuilder` measures the real content
    // width (page margin already removed) so the cells stay exact at 320–840dp.
    // A `Wrap` is used instead of a `GridView` because the page itself is the
    // scroll view — a nested grid would need its own bounded height.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 600 ? 3 : 2;
        const gap = 12.0;
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < DashboardSnapshot.relayCount; index++)
              SizedBox(
                width: itemWidth,
                child: RelayControlCard(
                  spec: relaySpecs[index],
                  isOn: _relayStates[index],
                  isPending: _pendingRelays.contains(index),
                  onToggle: () => _handleRelayTap(index, _relayStates[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}
