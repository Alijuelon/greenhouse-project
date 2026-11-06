import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/core/services/api_service.dart';

class AgriAppBar extends StatefulWidget implements PreferredSizeWidget {
  final int currentIndex;

  /// Source of the cosmetic settings payload (`user_name`, `avatar_url`,
  /// `is_online`). Injectable so widget tests never hit the network.
  final Future<Map<String, dynamic>> Function() settingsLoader;

  /// Pre-resolved avatar. When non-null it wins over `avatar_url`, which keeps
  /// tests and golden renders off `NetworkImage` entirely.
  final ImageProvider? avatarImage;

  const AgriAppBar({
    super.key,
    this.currentIndex = 0,
    this.settingsLoader = ApiService.getSettings,
    this.avatarImage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.appBarOuterHeight);

  @override
  State<AgriAppBar> createState() => _AgriAppBarState();
}

class _AgriAppBarState extends State<AgriAppBar> {
  Map<String, dynamic>? _settingsData;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await widget.settingsLoader();
      if (mounted) {
        setState(() => _settingsData = data);
      }
    } catch (_) {
      // Settings only drive cosmetic chrome (name, avatar, node liveness), so a
      // failed call falls back to the defaults below instead of logging noise.
      _settingsData = null;
    }
  }

  /// Avatar picture: injected image first, then the payload URL, then an icon.
  /// An empty/absent `avatar_url` must never produce a `NetworkImage('')`.
  Widget _buildAvatar(String avatarUrl) {
    final ImageProvider? provider =
        widget.avatarImage ??
        (avatarUrl.isEmpty ? null : NetworkImage(avatarUrl));
    if (provider == null) {
      return _avatarFallback();
    }
    return Image(
      image: provider,
      width: 34,
      height: 34,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _avatarFallback(),
    );
  }

  Widget _avatarFallback() => Container(
    width: 34,
    height: 34,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)],
      ),
    ),
    child: const Icon(
      Icons.person_rounded,
      size: 19,
      color: AppColors.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (_settingsData?['avatar_url'] as String?) ?? '';
    final name = (_settingsData?['user_name'] as String?) ?? 'User';
    // The shell only learns about node liveness through this payload; anything
    // missing or unknown reads as offline rather than a fake green light.
    final isOnline = _settingsData?['is_online'] == true;

    const pageTitles = [
      'Dashboard Monitoring',
      'Analitik Sensor',
      'AI Smart Dosing',
      'Aturan Otomasi',
      'Pengaturan Sistem',
    ];
    final activeSubtitle = widget.currentIndex < pageTitles.length
        ? pageTitles[widget.currentIndex]
        : 'Dashboard';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.marginMd,
          right: AppSpacing.marginMd,
          top: AppSpacing.spaceLg,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusXl3,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: AppSpacing.appBarHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFF3FAF5).withValues(alpha: 0.93),
                    const Color(0xFFEEF6FF).withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                borderRadius: AppRadius.radiusXl3,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    // Compact Logo + Title
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppColors.logoRingGradient,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(1.5),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9.5),
                              child: ColoredBox(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Image.asset(
                                    'assets/images/greenhouse_logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.eco_rounded,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Green House App',
                                  style: AppTextStyles.labelLg.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        activeSubtitle,
                                        style: AppTextStyles.labelSm.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    // Live Node Indicator Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOnline
                              ? [
                                  AppColors.primary.withValues(alpha: 0.12),
                                  AppColors.secondary.withValues(alpha: 0.08),
                                ]
                              : [
                                  AppColors.surfaceContainerLow,
                                  AppColors.surfaceContainerHigh,
                                ],
                        ),
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: isOnline
                              ? AppColors.primary.withValues(alpha: 0.24)
                              : AppColors.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOnline)
                            _PulsingDot(color: AppColors.success, size: 6)
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 5),
                          Text(
                            'Node 01',
                            style: AppTextStyles.caption.copyWith(
                              color: isOnline
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Profile avatar (Disinkronkan dengan database)
                    Semantics(
                      container: true,
                      label: 'Profil $name',
                      child: Tooltip(
                        message: name,
                        child: Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(1.8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.logoRingGradient,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: ClipOval(child: _buildAvatar(avatarUrl)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pulsing dot for Live indicator
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
