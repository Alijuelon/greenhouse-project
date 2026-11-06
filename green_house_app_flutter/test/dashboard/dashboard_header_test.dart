import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/summary_strip.dart';

/// Fixed clock so `resolveStatus` is deterministic (no `DateTime.now`).
final DateTime _now = DateTime(2026, 11, 5, 9, 0);

/// A healthy greenhouse payload, with knobs for the states under test.
DashboardSnapshot _snapshot({
  double? ph = 6.1,
  double? airTemp = 28.4,
  double? airHum = 72,
  double? ec = 420,
  double? soilTemp = 26.5,
  double? soilMoisture = 63,
  bool isOnline = true,
  DateTime? lastSeen,
  String aiMode = 'auto',
  bool hasLastSeen = true,
}) {
  return DashboardSnapshot(
    ph: ph,
    airTemp: airTemp,
    airHum: airHum,
    ec: ec,
    soilTemp: soilTemp,
    soilMoisture: soilMoisture,
    isOnline: isOnline,
    lastSeen: hasLastSeen ? lastSeen ?? _now : null,
    aiMode: aiMode,
  );
}

/// Hosts [child] at an exact content width + text scale so layout assertions
/// are deterministic regardless of the test surface.
Widget _host({
  required Widget child,
  double width = 360,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Mirrors the page: status/reasons are derived outside the widget.
DashboardHeader _header(
  DashboardSnapshot snapshot, {
  String updatedLabel = '8 dtk',
  VoidCallback? onRefresh,
}) {
  return DashboardHeader(
    snapshot: snapshot,
    status: resolveStatus(snapshot, now: _now),
    reasons: attentionReasons(snapshot),
    updatedLabel: updatedLabel,
    onRefresh: onRefresh ?? () {},
  );
}

void main() {
  group('DashboardHeader', () {
    testWidgets('pH 4.9 resolves to the Perlu perhatian chip', (
      WidgetTester tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(child: _header(_snapshot(ph: 4.9))));
      await tester.pumpAndSettle();

      expect(find.text('Perlu perhatian'), findsOneWidget);
      expect(find.text('Optimal'), findsNothing);
      expect(find.text('Offline'), findsNothing);

      // The reason is spelled out, not just implied by the chip colour.
      expect(find.textContaining('pH 4.9'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Status greenhouse: Perlu perhatian'),
        findsOneWidget,
      );

      semantics.dispose();
    });

    testWidgets('last_seen 20s in the past resolves to the Offline chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: _header(
            _snapshot(lastSeen: _now.subtract(const Duration(seconds: 20))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Optimal'), findsNothing);
      // Stale data is flagged as such, next to the freshness label.
      expect(find.text('Basi'), findsOneWidget);
    });

    testWidgets('a healthy snapshot shows Optimal and no Basi chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(child: _header(_snapshot())));
      await tester.pumpAndSettle();

      expect(find.text('Optimal'), findsOneWidget);
      expect(find.text('Basi'), findsNothing);
      expect(find.text('GREENHOUSE 01'), findsOneWidget);
    });

    testWidgets('the Diperbarui freshness label is always present', (
      WidgetTester tester,
    ) async {
      for (final updatedLabel in [
        '8 dtk',
        '2 mnt',
        '1 jam',
        'tidak diketahui',
      ]) {
        await tester.pumpWidget(
          _host(child: _header(_snapshot(), updatedLabel: updatedLabel)),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Diperbarui'),
          findsOneWidget,
          reason: 'missing freshness label for "$updatedLabel"',
        );
        expect(
          find.textContaining(updatedLabel),
          findsOneWidget,
          reason: 'age "$updatedLabel" must be shown verbatim',
        );
      }
    });

    testWidgets('the refresh button measures at least 48x48 and fires', (
      WidgetTester tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(
        _host(child: _header(_snapshot(), onRefresh: () => refreshes++)),
      );
      await tester.pumpAndSettle();

      final button = find.byType(IconButton);
      expect(button, findsOneWidget);

      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });
  });

  group('SummaryStrip', () {
    testWidgets('shows AI mode, running relays and the soil probe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(child: SummaryStrip(snapshot: _snapshot(), activeRelayCount: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mode AI'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.text('2 / 6'), findsOneWidget);
      expect(find.text('menyala'), findsOneWidget);
      expect(find.text('26.5°C'), findsOneWidget);
      expect(find.text('63% RH tanah'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('null soil readings render em dashes, never 0.0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: SummaryStrip(
            snapshot: _snapshot(soilTemp: null, soilMoisture: null),
            activeRelayCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Value and its unit label both fall back to the em dash.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0.0°C'), findsNothing);
      expect(find.text('0% RH tanah'), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header + strip: no overflow at 360dp with TextScaler 1.3', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 360,
          textScale: 1.3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(_snapshot(ph: 4.9, soilTemp: null, soilMoisture: null)),
              const SizedBox(height: 12),
              SummaryStrip(
                snapshot: _snapshot(
                  ph: 4.9,
                  soilTemp: null,
                  soilMoisture: null,
                ),
                activeRelayCount: 6,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow is reported through takeException, so this is the
      // assertion that the 1.3x probe actually checks layout, not just paint.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('overflowed'), findsNothing);
      expect(find.text('Perlu perhatian'), findsOneWidget);
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });
  });
}
