import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/climate_hero_card.dart';

/// Hosts the card at a fixed width so layout assertions are deterministic.
Widget host({
  double? temperature = 28.4,
  double? humidity = 72,
  GreenhouseStatus status = GreenhouseStatus.optimal,
  String updatedLabel = '8 dtk',
  double width = 360,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ClimateHeroCard(
            temperature: temperature,
            humidity: humidity,
            status: status,
            updatedLabel: updatedLabel,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the temperature and humidity readings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Suhu Udara'), findsOneWidget);
    expect(find.text('28.4'), findsOneWidget);
    expect(find.text('°C'), findsOneWidget);

    expect(find.text('Kelembapan'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('% RH'), findsOneWidget);

    expect(find.text('Optimal'), findsOneWidget);
    expect(find.text('Diperbarui 8 dtk lalu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null readings render an em dash, never 0.0', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(temperature: null, humidity: null));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(2));
    expect(find.textContaining('0.0'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline status shows the Offline pill and is announced', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(status: GreenhouseStatus.offline));
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Optimal'), findsNothing);
    expect(find.bySemanticsLabel('Status greenhouse: Offline'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('attention status shows the Perlu perhatian pill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(status: GreenhouseStatus.attention));
    await tester.pumpAndSettle();

    expect(find.text('Perlu perhatian'), findsOneWidget);
    expect(find.text('Optimal'), findsNothing);
  });

  testWidgets('no RenderFlex overflow at 360dp with TextScaler 1.3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        temperature: null,
        humidity: null,
        status: GreenhouseStatus.attention,
        textScaler: const TextScaler.linear(1.3),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Perlu perhatian'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Ideal 24–30°C'), findsOneWidget);
    expect(find.text('RH 60–80%'), findsOneWidget);
  });

  testWidgets('a new reading cross-fades in without leaving stale text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(temperature: 28.4));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(temperature: 31.2));
    await tester.pumpAndSettle();

    expect(find.text('31.2'), findsOneWidget);
    expect(find.text('28.4'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies glossy specular sheen and glass rim border', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final decoratedBoxes = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ClimateHeroCard),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .toList();

    expect(
      decoratedBoxes.any((d) => d.gradient is RadialGradient),
      isTrue,
      reason: 'botanical radial glow layer must be present',
    );
    expect(
      decoratedBoxes.any(
        (d) => d.gradient is LinearGradient && d.border != null,
      ),
      isTrue,
      reason: 'specular linear sheen + glass rim border must be present',
    );
  });
}
