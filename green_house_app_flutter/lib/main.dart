import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/app_bar_widget.dart';
import 'shared/widgets/bottom_nav_bar.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/analytics/presentation/pages/analytics_page.dart';
import 'features/ai_recommendation/presentation/pages/ai_recommendation_page.dart';
import 'features/automation/presentation/pages/automation_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const GreenHouseApp());
}

class GreenHouseApp extends StatelessWidget {
  const GreenHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green House App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(nextScreen: MainShell()),
    );
  }
}

/// Main shell: shared AppBar + BottomNavBar wrapping 4 tab pages.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Pages are rebuilt on every frame the shell rebuilds so the dashboard learns
  /// whether it owns the visible tab ([DashboardPage.isActive]) — that flag is
  /// what stops its polling while another tab is in front. Tab order and
  /// identity of the four other pages are unchanged, so they stay `const`.
  List<Widget> _buildPages() => <Widget>[
    DashboardPage(isActive: _currentIndex == 0),
    const AnalyticsPage(),
    const AIRecommendationPage(),
    const AutomationPage(),
    SettingsPage(isActive: _currentIndex == 4),
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AgriAppBar(currentIndex: _currentIndex),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          // The shell reserves the same slots the floating AppBar and dock
          // occupy (80 / 86) plus the system insets, so no page has to patch
          // its own top/bottom gap.
          padding: EdgeInsets.only(
            top: mediaQuery.padding.top + AppSpacing.appBarOuterHeight,
            bottom: AppSpacing.navBarOuterHeight + mediaQuery.padding.bottom,
          ),
          child: IndexedStack(index: _currentIndex, children: _buildPages()),
        ),
      ),
      bottomNavigationBar: AgriBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
