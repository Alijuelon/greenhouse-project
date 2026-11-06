import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:green_house_app/features/settings/presentation/pages/settings_page.dart';
import 'package:green_house_app/main.dart';

/// Fails every socket attempt instead of opening one, so the smoke test stays
/// hermetic: nothing in the shell (settings chrome, dashboard polling, avatars)
/// may depend on a reachable server.
class _RejectingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('network disabled for widget tests');
  }
}

void main() {
  setUp(() => HttpOverrides.global = _RejectingHttpOverrides());
  tearDown(() => HttpOverrides.global = null);

  testWidgets('App smoke test - verifies MainShell loads properly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    // Let the settings request and the first dashboard poll fail and rebuild.
    await tester.pump();

    expect(find.byType(MainShell), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Shell inset proof: the first page starts below the AppBar slot, not below
    // the old flat 64 magic number.
    final Rect dashboard = tester.getRect(find.byType(DashboardPage));
    // ignore: avoid_print
    print(
      '[widget_test] DashboardPage rect = $dashboard '
      '(appBar slot ${AppSpacing.appBarOuterHeight}, old magic 64)',
    );
    expect(dashboard.top, AppSpacing.appBarOuterHeight);

    // Unmount explicitly: the dashboard owns a periodic timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SettingsPage shows retry and Server URL actions when offline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SettingsPage())));
    await tester.pump();

    expect(find.text('Gagal memuat pengaturan.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
  });
}
