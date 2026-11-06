import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_motion.dart';
import 'package:green_house_app/core/theme/app_radius.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';

/// Floating Glass Dock Navigation Bar with haptic feedback & micro bounce
class AgriBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AgriBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.show_chart_rounded,
      activeIcon: Icons.show_chart_rounded,
      label: 'Analitik',
    ),
    _NavItem(
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology_rounded,
      label: 'AI Dosing',
    ),
    _NavItem(
      icon: Icons.tune_rounded,
      activeIcon: Icons.tune_rounded,
      label: 'Otomasi',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      // marginMd at the bottom keeps the dock slot at exactly
      // navBarHeight + 20 = 86 logical px, matching AppSpacing.navBarOuterHeight.
      padding: const EdgeInsets.only(
        left: AppSpacing.marginMd,
        right: AppSpacing.marginMd,
        bottom: AppSpacing.marginMd,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusXl3,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: AppSpacing.navBarHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceXs,
              vertical: AppSpacing.spaceXs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.88),
              borderRadius: AppRadius.radiusXl3,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.45),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: _NavButton(
                    item: item,
                    isActive: isActive,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(i);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isActive
        ? AppColors.accentInk
        : AppColors.textSecondary;
    final Duration duration = AppMotion.reduceMotion(context)
        ? Duration.zero
        : AppMotion.base;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              // accent is a fill-only token, so the pill uses the tinted
              // partner and the glyph/label use the text-safe ink.
              color: isActive ? AppColors.accentSoft : Colors.transparent,
              borderRadius: AppRadius.radiusXl,
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.radiusXl,
              splashColor: AppColors.accent.withValues(alpha: 0.18),
              highlightColor: AppColors.accent.withValues(alpha: 0.10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.12 : 1.0,
                    duration: duration,
                    curve: AppMotion.standard,
                    child: Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: AppTextStyles.labelSm.copyWith(
                      color: iconColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: duration,
                    curve: AppMotion.standard,
                    width: isActive ? 12 : 0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
