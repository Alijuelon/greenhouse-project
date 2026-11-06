import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/relay_control_card.dart';

/// Payload shaped exactly like `GET /api/dashboard/live`
/// (`flask_agrisense/app.py:326-352`) so the real mapper runs.
Map<String, dynamic> healthyPayload() => {
  'device_id': 'esp32_greenhouse_01',
  'is_online': true,
  'last_seen': DateTime(2026, 11, 5, 9, 0).toIso8601String(),
  'sensors': {
    'air_suhu': 28.4,
    'air_hum': 72.0,
    'tanah_suhu': 26.5,
    'tanah_lembap': 63.0,
    'ph': 6.1,
    'ec': 420.0,
    'n': 152.0,
    'p': 61.0,
    'k': 221.0,
    'soil_ok': true,
  },
  'relays': <bool>[false, false, false, false, false, false],
  'target_relays': <bool>[false, false, false, false, false, false],
  'ai': {'mode': 'auto'},
};

/// Pins the logical surface size for the duration of one test.
void useSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Real [DashboardPage] on an injected fake fetcher — never touches the network.
Widget host({TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: Scaffold(
          body: DashboardPage(
            isActive: false,
            pollInterval: null,
            clock: () => DateTime(2026, 11, 5, 9, 0),
            fetcher: () async => healthyPayload(),
          ),
        ),
      ),
    ),
  );
}

/// Runs [body] with layout errors captured instead of thrown, so the test can
/// assert "no RenderFlex overflowed" with the offending message attached.
Future<List<String>> captureFlutterErrors(Future<void> Function() body) async {
  final reported = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) => reported.add(details.exceptionAsString());
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
  return reported;
}

void main() {
  testWidgets('360dp lays the six relay cards out in two columns', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(360, 900));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final cards = find.byType(RelayControlCard);
    expect(cards, findsNWidgets(6));

    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    final dy1 = tester.getTopLeft(cards.at(1)).dy;
    final dy2 = tester.getTopLeft(cards.at(2)).dy;
    debugPrint('360dp top-left dy -> card0=$dy0 card1=$dy1 card2=$dy2');

    expect(
      dy1,
      moreOrLessEquals(dy0, epsilon: 0.01),
      reason: 'cards 0 and 1 must share the first column row',
    );
    expect(
      dy2,
      greaterThan(dy0 + 1),
      reason: 'card 2 must start the second column row',
    );

    // No leftover `SizedBox(width: 10)` gap: both cells are exactly equal.
    final w0 = tester.getSize(cards.at(0)).width;
    final w1 = tester.getSize(cards.at(1)).width;
    debugPrint('360dp card widths -> card0=$w0 card1=$w1');
    expect(w1, moreOrLessEquals(w0, epsilon: 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('800dp lays the six relay cards out in three columns', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(800, 1200));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final cards = find.byType(RelayControlCard);
    expect(cards, findsNWidgets(6));

    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    final dy1 = tester.getTopLeft(cards.at(1)).dy;
    final dy2 = tester.getTopLeft(cards.at(2)).dy;
    final dy3 = tester.getTopLeft(cards.at(3)).dy;
    debugPrint(
      '800dp top-left dy -> card0=$dy0 card1=$dy1 card2=$dy2 card3=$dy3',
    );

    expect(dy1, moreOrLessEquals(dy0, epsilon: 0.01));
    expect(dy2, moreOrLessEquals(dy0, epsilon: 0.01));
    expect(
      dy3,
      greaterThan(dy0 + 1),
      reason: 'card 3 must wrap onto the second row of a 3-column grid',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp at 1.3x text scale renders six cards without overflow', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(320, 1400));

    final reported = await captureFlutterErrors(() async {
      await tester.pumpWidget(host(textScaler: const TextScaler.linear(1.3)));
      await tester.pumpAndSettle();
    });

    expect(find.byType(RelayControlCard), findsNWidgets(6));
    debugPrint('320dp/1.3x flutter errors -> $reported');
    expect(
      reported.where((message) => message.contains('overflowed')),
      isEmpty,
      reason: reported.join('\n'),
    );
    expect(reported, isEmpty, reason: reported.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('actuator header renders at 360dp / 1.3x without overflow', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(360, 1400));

    final reported = await captureFlutterErrors(() async {
      await tester.pumpWidget(host(textScaler: const TextScaler.linear(1.3)));
      await tester.pumpAndSettle();
    });

    expect(find.text('Kontrol Aktuator'), findsOneWidget);
    expect(find.text('0 / 6 aktif'), findsOneWidget);
    expect(find.text('Atur Durasi'), findsOneWidget);
    debugPrint('360dp/1.3x flutter errors -> $reported');
    expect(reported, isEmpty, reason: reported.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Atur Durasi" is at least a 48dp tap target', (
    WidgetTester tester,
  ) async {
    useSurface(tester, const Size(360, 900));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('dashboard-atur-durasi'));
    expect(button, findsOneWidget);

    final size = tester.getSize(button);
    debugPrint('"Atur Durasi" size -> ${size.width} x ${size.height}');
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
