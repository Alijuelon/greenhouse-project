import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/npk_7_in_1_card.dart';

/// A complete, healthy probe payload.
DashboardSnapshot fullSnapshot({
  double? n = 160,
  double? p = 45,
  double? k = 210,
  double? ph = 6.1,
  double? ec = 420,
  double? soilTemp = 26.5,
  double? soilMoisture = 55,
  bool isOnline = true,
  bool soilOk = true,
}) {
  return DashboardSnapshot(
    n: n,
    p: p,
    k: k,
    ph: ph,
    ec: ec,
    soilTemp: soilTemp,
    soilMoisture: soilMoisture,
    isOnline: isOnline,
    soilOk: soilOk,
  );
}

/// Hosts the card at an exact width so layout assertions are deterministic.
Widget host({
  required DashboardSnapshot snapshot,
  double width = 360,
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: width,
              child: Npk7In1Card(snapshot: snapshot),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'full payload renders N/P/K tiles and all four secondary metrics',
    (WidgetTester tester) async {
      await tester.pumpWidget(host(snapshot: fullSnapshot()));
      await tester.pumpAndSettle();

      // NPK letters + labels + readings + targets.
      expect(find.text('N'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      expect(find.text('Nitrogen'), findsOneWidget);
      expect(find.text('Fosfor'), findsOneWidget);
      expect(find.text('Kalium'), findsOneWidget);
      expect(find.text('160'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('mg/kg'), findsNWidgets(3));
      expect(find.text('Target 150'), findsOneWidget);
      expect(find.text('Target 60'), findsOneWidget);
      expect(find.text('Target 220'), findsOneWidget);

      // Secondary grid: pH, EC, soil temperature, soil moisture.
      expect(find.text('pH'), findsOneWidget);
      expect(find.text('6.1'), findsOneWidget);
      expect(find.text('EC'), findsOneWidget);
      expect(find.text('420'), findsOneWidget);
      expect(find.text('Suhu Tanah'), findsOneWidget);
      expect(find.text('26.5'), findsOneWidget);
      expect(find.text('Kelembapan Tanah'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);

      // All four readings sit inside their ideal window.
      expect(find.text('Ideal'), findsNWidgets(4));
      expect(find.text('Tidak ada data'), findsNothing);

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Basi'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('null readings render an em dash and no alarm text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(snapshot: fullSnapshot(n: null, ph: null, ec: null)),
    );
    await tester.pumpAndSettle();

    // N, pH and EC have no reading → three em dashes, never a zero.
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('Tidak ada data'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
    expect(find.text('0.0'), findsNothing);

    // No fabricated alarm for a reading the probe did not send.
    expect(find.textContaining('Rendah'), findsNothing);
    expect(find.textContaining('Koreksi'), findsNothing);
    expect(find.textContaining('⚠'), findsNothing);

    // The readings that *are* present still render normally.
    expect(find.text('210'), findsOneWidget);
    expect(find.text('26.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty payload replaces the body with the not-detected panel',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          snapshot: fullSnapshot(
            n: null,
            p: null,
            k: null,
            ph: null,
            ec: null,
            soilTemp: null,
            soilMoisture: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sensor 7-in-1 tidak terdeteksi'), findsOneWidget);
      expect(
        find.text('Periksa kabel probe dan daya sensor pada perangkat.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.sensors_off), findsOneWidget);

      // The metric tiles are gone, not just blanked.
      expect(find.text('Target 150'), findsNothing);
      expect(find.text('Tidak ada data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('soilOk false adds the Tanah bermasalah chip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(snapshot: fullSnapshot(soilOk: false)));
    await tester.pumpAndSettle();

    expect(find.text('Tanah bermasalah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline payload shows the Basi freshness chip', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(snapshot: fullSnapshot(isOnline: false)));
    await tester.pumpAndSettle();

    expect(find.text('Basi'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.bySemanticsLabel('Status data nutrisi: Basi'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('no RenderFlex overflow at 360dp with TextScaler 1.3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        snapshot: fullSnapshot(
          n: null,
          p: 45,
          k: 210,
          ph: null,
          ec: 420,
          soilTemp: 26.5,
          soilMoisture: 55,
          soilOk: false,
        ),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tanah bermasalah'), findsOneWidget);
    // pH has no reading; EC still does.
    expect(find.text('Tidak ada data'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
  });
}
