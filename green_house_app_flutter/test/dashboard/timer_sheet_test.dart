import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/presentation/widgets/timer_bottom_sheet.dart';

/// Minimal host that opens the sheet through its public entry point
/// (`TimerBottomSheet.show`) and records whatever value it resolves with.
class _SheetHost extends StatefulWidget {
  const _SheetHost();

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  int? _result;
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              key: const Key('open-sheet'),
              onPressed: () async {
                final result = await TimerBottomSheet.show(context);
                if (!mounted) return;
                setState(() {
                  _result = result;
                  _resolved = true;
                });
              },
              child: const Text('Buka'),
            ),
            Text('hasil: ${_resolved ? '$_result' : 'belum'}'),
          ],
        ),
      ),
    );
  }
}

Future<void> pumpHost(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const _SheetHost(),
    ),
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders all five duration chips', (tester) async {
    await pumpHost(tester);
    await openSheet(tester);

    for (final minutes in ['5', '10', '15', '30', '60']) {
      expect(
        find.text(minutes),
        findsOneWidget,
        reason: 'chip "$minutes" harus dirender',
      );
      expect(find.byKey(Key('timer-chip-$minutes')), findsOneWidget);
    }
  });

  testWidgets('tapping 60 then confirming resolves the sheet with 60', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('timer-chip-60')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('timer-sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('hasil: 60'), findsOneWidget);
    expect(find.byKey(const Key('timer-chip-60')), findsNothing);
  });

  testWidgets('close button is >= 48x48 and dismisses with no value', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    final close = find.byKey(const Key('timer-sheet-close'));
    final size = tester.getSize(close);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));

    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.text('hasil: null'), findsOneWidget);
  });

  testWidgets('every duration chip is at least a 48x48 tap target', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    for (final minutes in ['5', '10', '15', '30', '60']) {
      final size = tester.getSize(find.byKey(Key('timer-chip-$minutes')));
      expect(
        size.width,
        greaterThanOrEqualTo(48.0),
        reason: 'chip $minutes terlalu sempit: ${size.width}',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(48.0),
        reason: 'chip $minutes terlalu pendek: ${size.height}',
      );
    }
  });

  testWidgets('chips expose button semantics with selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHost(tester);
    await openSheet(tester);

    final selected = tester.getSemantics(
      find.byKey(const Key('timer-chip-10')),
    );
    final data = selected.getSemanticsData();
    expect(data.label, '10 menit');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);

    final unselected = tester.getSemantics(
      find.byKey(const Key('timer-chip-60')),
    );
    final unselectedData = unselected.getSemanticsData();
    expect(unselectedData.label, '60 menit');
    expect(unselectedData.flagsCollection.isButton, isTrue);
    expect(unselectedData.flagsCollection.isSelected, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('copy names Pompa Irigasi and never mentions melon', (
    tester,
  ) async {
    await pumpHost(tester);
    await openSheet(tester);

    expect(find.textContaining('melon'), findsNothing);
    expect(find.textContaining('Pompa Irigasi'), findsOneWidget);
  });

  testWidgets('320dp at 1.3x text scale renders without overflow', (
    tester,
  ) async {
    await pumpHost(
      tester,
      size: const Size(320, 800),
      textScaler: const TextScaler.linear(1.3),
    );
    await openSheet(tester);

    expect(tester.takeException(), isNull);

    // Every chip is still reachable and tappable under large text.
    for (final minutes in ['5', '10', '15', '30', '60']) {
      expect(find.byKey(Key('timer-chip-$minutes')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('timer-chip-60')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timer-sheet-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('hasil: 60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
