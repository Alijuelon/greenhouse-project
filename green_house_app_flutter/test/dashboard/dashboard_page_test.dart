import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/climate_hero_card.dart';

/// Payload shaped exactly like `GET /api/dashboard/live`
/// (`flask_agrisense/app.py:326-352`), so the mapper is exercised for real.
Map<String, dynamic> healthyPayload({List<bool>? targetRelays}) => {
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
  'target_relays':
      targetRelays ?? <bool>[false, false, false, false, false, false],
  'ai': {'mode': 'auto'},
};

/// Local fake: a plain function, no mock package, no network.
Widget host({
  required Future<Map<String, dynamic>> Function() fetcher,
  bool isActive = true,
  Duration? pollInterval = const Duration(seconds: 5),
  DateTime Function()? clock,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DashboardPage(
        isActive: isActive,
        fetcher: fetcher,
        pollInterval: pollInterval,
        clock: clock,
      ),
    ),
  );
}

void main() {
  group('DashboardPage state machine', () {
    testWidgets('shows the skeleton before the fetcher completes', (
      WidgetTester tester,
    ) async {
      final completer = Completer<Map<String, dynamic>>();

      await tester.pumpWidget(
        host(fetcher: () => completer.future, pollInterval: null),
      );
      await tester.pump();

      expect(find.byKey(const Key('dashboard-skeleton')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-cold-error')), findsNothing);
      expect(find.byType(ClimateHeroCard), findsNothing);

      completer.complete(healthyPayload());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-skeleton')), findsNothing);
      expect(find.byType(ClimateHeroCard), findsOneWidget);
    });

    testWidgets('renders content when the fetcher resolves', (
      WidgetTester tester,
    ) async {
      var calls = 0;

      await tester.pumpWidget(
        host(
          pollInterval: null,
          fetcher: () async {
            calls++;
            return healthyPayload();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byType(ClimateHeroCard), findsOneWidget);
      // Temperature from `sensors.air_suhu`, no fabricated 0.0 fallback.
      expect(find.text('28.4'), findsOneWidget);
      expect(find.text('Greenhouse 01'), findsOneWidget);
      expect(find.text('Dosing Pupuk A'), findsOneWidget);
      // Actuator section chip (T6 copy: `0 / 6 aktif`).
      expect(find.text('0 / 6 aktif'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-stale-banner')), findsNothing);
    });

    testWidgets('renders a cold error when the fetcher rejects with no data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          pollInterval: null,
          fetcher: () async => throw Exception('server 500'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-cold-error')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-skeleton')), findsNothing);
      expect(find.text('Koneksi Gagal'), findsOneWidget);
      expect(find.textContaining('server 500'), findsOneWidget);

      final retry = find.widgetWithText(ElevatedButton, 'Coba Lagi');
      expect(retry, findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      'keeps old data and shows StaleBanner when a later poll fails',
      (WidgetTester tester) async {
        var now = DateTime(2026, 11, 5, 9, 0);
        var calls = 0;

        await tester.pumpWidget(
          host(
            clock: () => now,
            pollInterval: const Duration(seconds: 5),
            fetcher: () async {
              calls++;
              if (calls == 1) return healthyPayload();
              throw Exception('gateway timeout');
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(calls, 1);
        expect(find.byType(ClimateHeroCard), findsOneWidget);
        expect(find.byKey(const Key('dashboard-stale-banner')), findsNothing);

        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(seconds: 5)); // poll tick → failure
        await tester.pump();

        expect(calls, 2);
        expect(find.byKey(const Key('dashboard-stale-banner')), findsOneWidget);
        expect(
          find.text('Gagal memperbarui • data 2 mnt lalu'),
          findsOneWidget,
        );
        // Stale state: the previous reading is still on screen.
        expect(find.byType(ClimateHeroCard), findsOneWidget);
        expect(find.text('28.4'), findsOneWidget);
        expect(find.text('Koneksi Gagal'), findsNothing);
      },
    );

    testWidgets('pollInterval null leaves no pending timer', (
      WidgetTester tester,
    ) async {
      var calls = 0;

      await tester.pumpWidget(
        host(
          pollInterval: null,
          fetcher: () async {
            calls++;
            return healthyPayload();
          },
        ),
      );
      // Would throw "A Timer is still pending" if a timer existed.
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(calls, 1);
      expect(find.byType(ClimateHeroCard), findsOneWidget);
    });

    testWidgets('isActive false never starts polling (exactly one call)', (
      WidgetTester tester,
    ) async {
      var calls = 0;

      await tester.pumpWidget(
        host(
          isActive: false,
          pollInterval: const Duration(seconds: 1),
          fetcher: () async {
            calls++;
            return healthyPayload();
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(calls, 1);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(calls, 1, reason: 'inactive tab must not poll');
      expect(find.byType(ClimateHeroCard), findsOneWidget);
    });

    testWidgets('hung fetcher times out after 4s instead of freezing', (
      WidgetTester tester,
    ) async {
      var calls = 0;
      final never = Completer<Map<String, dynamic>>();

      await tester.pumpWidget(
        host(
          pollInterval: null,
          fetcher: () {
            calls++;
            return calls == 1 ? never.future : Future.value(healthyPayload());
          },
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dashboard-skeleton')), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(calls, 1);
      expect(find.byKey(const Key('dashboard-skeleton')), findsNothing);
      expect(find.text('Koneksi Gagal'), findsOneWidget);
      expect(find.textContaining('tidak merespons'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Coba Lagi'));
      await tester.pumpAndSettle();

      expect(calls, 2, reason: 'retry must hit the fetcher again');
      expect(find.byType(ClimateHeroCard), findsOneWidget);
      expect(find.text('Koneksi Gagal'), findsNothing);
    });

    testWidgets(
      'rejected relay command reverts and surfaces the server message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          host(pollInterval: null, fetcher: () async => healthyPayload()),
        );
        await tester.pumpAndSettle();

        expect(find.text('0 / 6 aktif'), findsOneWidget);

        // Exhaust Blower (index 4) is not protected → no confirmation dialog.
        final blower = find.text('Exhaust Blower');
        await tester.ensureVisible(blower);
        await tester.pumpAndSettle();
        await tester.tap(blower);
        await tester.pumpAndSettle();

        // `ApiService.toggleRelay` cannot succeed in the test environment
        // (flutter_test answers every HTTP request with 400), so the page must
        // take its reject path: revert the optimistic state + explain why.
        expect(find.text('Perintah relay ditolak server'), findsOneWidget);
        expect(find.text('0 / 6 aktif'), findsOneWidget);

        // Drain the SnackBar timer so teardown has nothing pending.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });
}
