// Widget-level coverage for M4's `advanceOnClick` (design decision #4): a
// tap inside the hole both reaches the highlighted target's own gesture
// handler (mirroring JS's bubble-phase event handling — no
// `preventDefault`/`stopPropagation`) and advances the tour when the
// effective `advanceOnClick` (step overrides config) is on; it's a no-op
// (target still gets its own tap) when off, and doesn't fire while a
// highlight transition is mid-flight.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, List<GlobalKey>, List<bool>)> _pumpApp(
  WidgetTester tester,
) async {
  final keys = List.generate(2, (_) => GlobalKey());
  final tapped = List.filled(2, false);
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return Stack(
              children: [
                for (var i = 0; i < keys.length; i++)
                  Positioned(
                    left: 20.0 + i * 150,
                    top: 20,
                    child: GestureDetector(
                      onTap: () => tapped[i] = true,
                      child: SizedBox(
                        key: keys[i],
                        width: 100,
                        height: 40,
                        child: ColoredBox(color: Colors.primaries[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  return (appContext, keys, tapped);
}

void main() {
  testWidgets(
    'advanceOnClick:true fires the target\'s own onTap AND advances to the '
    'next step',
    (tester) async {
      final (appContext, keys, tapped) = await _pumpApp(tester);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(element: keys[0], advanceOnClick: true),
            DriveStep(element: keys[1]),
          ],
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(70, 40));
      await tester.pumpAndSettle();

      expect(tapped[0], isTrue);
      expect(d.getActiveIndex(), 1);
    },
  );

  testWidgets(
    'advanceOnClick:false (default) only fires the target\'s own tap, no '
    'advance',
    (tester) async {
      final (appContext, keys, tapped) = await _pumpApp(tester);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(element: keys[0]),
            DriveStep(element: keys[1]),
          ],
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(70, 40));
      await tester.pumpAndSettle();

      expect(tapped[0], isTrue);
      expect(d.getActiveIndex(), 0);
    },
  );

  testWidgets(
    "advanceOnClick doesn't fire while a highlight transition is mid-flight",
    (tester) async {
      final (appContext, keys, tapped) = await _pumpApp(tester);

      final d = driver(
        DriverConfig(
          context: appContext,
          duration: const Duration(milliseconds: 300),
          steps: [
            DriveStep(element: keys[0], advanceOnClick: true),
            DriveStep(element: keys[1], advanceOnClick: true),
          ],
        ),
      );

      d.drive(0);
      // Deliberately not settled: the stage-chase ticker still owns
      // `transitionToken` here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tapAt(const Offset(70, 40));
      await tester.pump();

      // The tap landed mid-transition — `_handleHoleTap` bails on the
      // `transitionToken != null` guard before it ever schedules an
      // advance, so the index is still 0 once everything settles.
      await tester.pumpAndSettle();
      expect(d.getActiveIndex(), 0);
    },
  );

  testWidgets('config-level advanceOnClick applies to every step', (
    tester,
  ) async {
    final (appContext, keys, tapped) = await _pumpApp(tester);

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        advanceOnClick: true,
        steps: [
          DriveStep(element: keys[0]),
          DriveStep(element: keys[1]),
        ],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(70, 40));
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 1);
  });
}
