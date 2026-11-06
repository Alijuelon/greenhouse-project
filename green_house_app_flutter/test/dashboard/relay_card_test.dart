import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/relay_spec.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/relay_control_card.dart';

/// Hosts one card at an exact width so layout assertions are deterministic.
Widget host({
  RelaySpec? spec,
  bool isOn = false,
  bool isPending = false,
  VoidCallback? onToggle,
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
              child: RelayControlCard(
                spec: spec ?? relaySpecs[0],
                isOn: isOn,
                isPending: isPending,
                onToggle: onToggle ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('relaySpecs has 6 ESP32 channels, first four protected', () {
    expect(relaySpecs.length, 6);
    expect(relaySpecs.map((s) => s.index).toList(), [0, 1, 2, 3, 4, 5]);
    expect(relaySpecs.take(4).every((s) => s.isProtected), isTrue);
    expect(relaySpecs.skip(4).any((s) => s.isProtected), isFalse);

    // Protected channels must explain themselves; free ones must not.
    for (final spec in relaySpecs) {
      expect(spec.name, isNotEmpty);
      expect(spec.shortName, isNotEmpty);
      if (spec.isProtected) {
        expect(spec.description, isNotEmpty, reason: spec.name);
      }
    }

    expect(RelaySpec.byIndex(5).name, 'Pompa Irigasi');
    expect(relaySpecs[4].shortName, 'Blower');
  });

  testWidgets('tapping the card body calls onToggle exactly once', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(host(spec: relaySpecs[4], onToggle: () => calls++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exhaust Blower'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the switch calls onToggle exactly once', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(spec: relaySpecs[5], isOn: false, onToggle: () => calls++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('semantics expose a toggled button labelled with name+status', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(spec: relaySpecs[0], isOn: true));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(RelayControlCard));
    // Printed on purpose: the accessibility assertions must be inspectable in
    // CI output, not just trusted.
    debugPrint('--- semantics tree ---');
    debugPrint(node.toStringDeep());
    debugPrint('----------------------');

    expect(
      node,
      isSemantics(
        label: 'Dosing Pupuk A, Aktif',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );

    // Exactly one control per card: the icon, chips and inner switch are not
    // announced again as children.
    var childCount = 0;
    node.visitChildren((child) {
      childCount++;
      return true;
    });
    expect(childCount, 0);

    // The inner Switch is excluded: exactly one toggle node per card.
    expect(find.bySemanticsLabel('Dosing Pupuk A, Aktif'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('off + protected reports toggled: false and "Terlindungi"', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(spec: relaySpecs[3], isOn: false));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(RelayControlCard));
    debugPrint(node.toStringDeep());

    expect(
      node,
      isSemantics(
        label: 'pH Down, Terlindungi',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    expect(find.text('Terlindungi'), findsOneWidget);
    expect(find.text('Siaga'), findsNothing);

    handle.dispose();
  });

  testWidgets('free relay off shows "Siaga"', (WidgetTester tester) async {
    await tester.pumpWidget(host(spec: relaySpecs[4]));
    await tester.pumpAndSettle();

    expect(find.text('Siaga'), findsOneWidget);
    expect(find.text('Terlindungi'), findsNothing);
    expect(find.text('Aktif'), findsNothing);
  });

  testWidgets('isPending renders "Menunggu perangkat" and locks the switch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(spec: relaySpecs[2], isOn: false, isPending: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menunggu perangkat'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card is at least 48x48 in both axes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(spec: relaySpecs[0]));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(RelayControlCard));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'narrow 160dp + TextScaler 1.3 with pending chip does not throw',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          spec: relaySpecs[0],
          isOn: false,
          isPending: true,
          width: 160,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The name is clamped to two lines with an ellipsis, so it can never
      // paint outside the tile.
      final nameText = tester.widget<Text>(find.text('Dosing Pupuk A'));
      expect(nameText.maxLines, 2);
      expect(nameText.overflow, TextOverflow.ellipsis);

      final cardWidth = tester.getSize(find.byType(RelayControlCard)).width;
      final nameWidth = tester.getSize(find.text('Dosing Pupuk A')).width;
      expect(nameWidth, lessThanOrEqualTo(cardWidth));
    },
  );
}
