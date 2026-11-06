import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/core/theme/app_theme.dart';
import 'package:green_house_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/climate_hero_card.dart';

import '../support/fake_dashboard.dart';

/// The two surfaces every state is locked at: a mid-range phone and a tablet.
const List<Size> _surfaces = <Size>[Size(360, 800), Size(800, 1280)];

/// Every bundled weight is registered under its family so text renders with
/// the real typeface instead of flutter_test's placeholder "Ahem" boxes.
const List<String> _plusJakartaFiles = <String>[
  'PlusJakartaSans-Regular.ttf',
  'PlusJakartaSans-Medium.ttf',
  'PlusJakartaSans-SemiBold.ttf',
  'PlusJakartaSans-Bold.ttf',
  'PlusJakartaSans-ExtraBold.ttf',
];

const List<String> _interFiles = <String>[
  'Inter-Regular.ttf',
  'Inter-Medium.ttf',
  'Inter-SemiBold.ttf',
  'Inter-Bold.ttf',
];

/// MaterialIcons is what draws every icon on the dashboard. Without it icons
/// render as empty squares, which would silently poison all eight goldens.
const String _materialIconsAsset = 'fonts/MaterialIcons-Regular.otf';

Future<void> _loadFamily(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load('assets/fonts/$asset'));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFamily('PlusJakartaSans', _plusJakartaFiles);
    await _loadFamily('Inter', _interFiles);

    try {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load(_materialIconsAsset));
      await icons.load();
    } catch (error) {
      // Deliberately loud: goldens captured without this font are worthless as
      // design evidence, so a missing icon font must fail, not skip.
      fail(
        'MaterialIcons font could not be loaded from "$_materialIconsAsset" '
        '($error). Every golden would show empty squares instead of icons; '
        'refusing to record design evidence with a fallback font.',
      );
    }
  });

  /// Pins the logical surface for one test and restores it afterwards.
  void useSurface(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Widget host({
    required Future<Map<String, dynamic>> Function() fetcher,
    bool isActive = false,
    Duration? pollInterval,
    DateTime Function()? clock,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: DashboardPage(
          isActive: isActive,
          pollInterval: pollInterval,
          fetcher: fetcher,
          clock: clock ?? () => kFixedNow,
        ),
      ),
    );
  }

  /// Decodes the hero logo for real; without this the `Image.asset` in
  /// `ClimateHeroCard` may not have painted by the time the golden is taken.
  Future<void> precacheLogo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/greenhouse_logo.png'),
        tester.element(find.byType(DashboardPage)),
      );
    });
  }

  /// Pumps until the first fetch resolved and all animations settled.
  Future<void> pumpDashboard(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(); // initState fetch → first frame with data
    await precacheLogo(tester);
    await tester.pumpAndSettle();
  }

  String goldenPath(String state, Size size) =>
      'goldens/${state}_${size.width.toInt()}.png';

  for (final size in _surfaces) {
    final width = size.width.toInt();

    testWidgets('golden: healthy $width', (WidgetTester tester) async {
      useSurface(tester, size);
      await pumpDashboard(tester, host(fetcher: () async => healthyPayload()));

      // A golden of the skeleton or of an error page would "pass" while
      // proving nothing — pin the actual data state first.
      expect(find.byKey(const Key('dashboard-skeleton')), findsNothing);
      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.byKey(const Key('dashboard-stale-banner')), findsNothing);
      expect(find.text('27.6'), findsOneWidget);
      expect(find.text('2 / 6 aktif'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(goldenPath('healthy', size)),
      );
    });

    testWidgets('golden: stale $width', (WidgetTester tester) async {
      useSurface(tester, size);

      // Polling (not the refresh button) is the specified trigger, and polling
      // only arms while the tab is active — hence `isActive: true` here.
      var calls = 0;
      var now = kFixedNow;

      await tester.pumpWidget(
        host(
          isActive: true,
          pollInterval: const Duration(seconds: 5),
          clock: () => now,
          fetcher: () async {
            calls++;
            if (calls == 1) return healthyPayload();
            throw Exception('gateway timeout');
          },
        ),
      );
      await tester.pump();
      await precacheLogo(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.byKey(const Key('dashboard-stale-banner')), findsNothing);

      // Second poll fires at +5 s and fails; the fixed clock moves with it so
      // the banner text stays deterministic ("data 6 dtk lalu").
      now = kFixedNow.add(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(calls, 2);
      expect(find.byKey(const Key('dashboard-stale-banner')), findsOneWidget);
      // Old readings stay on screen behind the banner.
      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.text('27.6'), findsOneWidget);
      expect(find.text('Koneksi Gagal'), findsNothing);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(goldenPath('stale', size)),
      );

      // Drain the poll timer so teardown has nothing pending.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('golden: empty_sensors $width', (WidgetTester tester) async {
      useSurface(tester, size);
      await pumpDashboard(
        tester,
        host(fetcher: () async => emptySensorsPayload()),
      );

      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.text('Sensor 7-in-1 tidak terdeteksi'), findsOneWidget);
      // Missing readings are "—", never a fabricated 0.0.
      expect(find.text('0.0'), findsNothing);
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(goldenPath('empty_sensors', size)),
      );
    });

    testWidgets('golden: partial $width', (WidgetTester tester) async {
      useSurface(tester, size);
      await pumpDashboard(tester, host(fetcher: () async => partialPayload()));

      // Short `target_relays` (3 of 6) must be padded, not crash.
      expect(tester.takeException(), isNull);
      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.text('29.1'), findsOneWidget);
      expect(find.text('Tidak ada data'), findsWidgets);

      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(goldenPath('partial', size)),
      );
    });
  }
}
