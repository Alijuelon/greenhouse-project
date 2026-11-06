import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/shared/widgets/app_bar_widget.dart';
import 'package:green_house_app/shared/widgets/bottom_nav_bar.dart';

/// Geometry test for the shell slots.
///
/// It pins the contract the pages rely on: the floating AppBar occupies
/// [AppSpacing.appBarOuterHeight] plus the status-bar inset, and the floating
/// dock occupies [AppSpacing.navBarOuterHeight] at the bottom — on top of the
/// system inset. The body probe must never slide under either one.
void main() {
  const Key probeKey = Key('shell-body-probe');
  const Size surface = Size(360, 800);

  Future<Map<String, dynamic>> fakeSettingsLoader() async => <String, dynamic>{
    'user_name': 'Operator Uji',
    'avatar_url': '',
    'is_online': false,
  };

  Widget harness({double topInset = 0, double bottomInset = 0}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQueryData(
          size: surface,
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        appBar: AgriAppBar(settingsLoader: fakeSettingsLoader),
        body: SizedBox.expand(
          child: KeyedSubtree(key: probeKey, child: const SizedBox.expand()),
        ),
        bottomNavigationBar: AgriBottomNavBar(currentIndex: 0, onTap: (_) {}),
      ),
    );
  }

  Future<Rect> pumpAndMeasure(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(app);
    await tester.pump();

    final Rect rect = tester.getRect(find.byKey(probeKey));
    // Printed on purpose: the evidence file must show real numbers, not a
    // pass/fail that could hide a wrong inset.
    // ignore: avoid_print
    print('[shell_layout] body probe rect = $rect (surface $surface)');
    return rect;
  }

  testWidgets('body never slides under the AppBar or the dock (no inset)', (
    WidgetTester tester,
  ) async {
    final Rect rect = await pumpAndMeasure(tester, harness());

    expect(
      rect.top,
      greaterThanOrEqualTo(AppSpacing.appBarOuterHeight),
      reason:
          'body top ${rect.top} must clear the AppBar slot '
          '(${AppSpacing.appBarOuterHeight})',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(surface.height - AppSpacing.navBarOuterHeight),
      reason:
          'body bottom ${rect.bottom} must stay above the dock slot '
          '(${surface.height - AppSpacing.navBarOuterHeight})',
    );

    // The visible chrome must keep its old rendered heights: the AppBar bar is
    // 64 logical px tall, the dock 66, inside an 86 px slot.
    final Size bar = tester.getSize(
      find
          .descendant(
            of: find.byType(AgriAppBar),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    final Size dock = tester.getSize(find.byType(AgriBottomNavBar));
    final Size dockInner = tester.getSize(
      find
          .descendant(
            of: find.byType(AgriBottomNavBar),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    // ignore: avoid_print
    print(
      '[shell_layout] appBar bar size = $bar, dock slot size = $dock, '
      'dock bar size = $dockInner',
    );
    expect(bar.height, AppSpacing.appBarHeight);
    expect(dockInner.height, AppSpacing.navBarHeight);
    expect(dock.height, AppSpacing.navBarOuterHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nav items and avatar expose semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await pumpAndMeasure(tester, harness());

      // One label per destination, provided by the wrapper (the child text is
      // excluded so nothing is announced twice).
      expect(find.bySemanticsLabel('Dashboard'), findsOneWidget);
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      // The avatar reads as a profile, not just as an unlabeled image.
      expect(find.bySemanticsLabel('Profil Operator Uji'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('body follows the status-bar inset on top of the AppBar slot', (
    WidgetTester tester,
  ) async {
    const double inset = 24;
    final Rect rect = await pumpAndMeasure(tester, harness(topInset: inset));

    // The stale-state guard: the old shell inlaid a flat 64/64 pair. With a
    // 24px status bar a 64-only inset would land at 64 or 88, both below the
    // 104 asserted here.
    expect(
      rect.top,
      greaterThanOrEqualTo(inset + AppSpacing.appBarOuterHeight),
      reason:
          'body top ${rect.top} must be at least status inset $inset + AppBar '
          'slot ${AppSpacing.appBarOuterHeight}',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(surface.height - AppSpacing.navBarOuterHeight),
      reason: 'body bottom ${rect.bottom} must stay above the dock slot',
    );
    expect(tester.takeException(), isNull);
  });
}
