// Coverage for design decision #12's tour<->hints coordination via
// `DriverRegistry.activeTourCount`: starting a tour hides an already-shown
// `Hints` instance (without losing its own visible/dismissed state),
// destroying the tour brings it back, and two concurrent
// tours/highlights net the shared counter correctly.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/hint_widgets.dart';
import 'package:driverjs/src/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, GlobalKey, GlobalKey)> _pumpApp(
  WidgetTester tester,
) async {
  final hintKey = GlobalKey();
  final tourKey = GlobalKey();
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 20,
                  child: SizedBox(key: hintKey, width: 30, height: 30),
                ),
                Positioned(
                  left: 200,
                  top: 200,
                  child: SizedBox(key: tourKey, width: 30, height: 30),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  return (appContext, hintKey, tourKey);
}

void main() {
  setUp(() {
    // The counter is process-wide; start every test from a clean slate in
    // case a previous test in this run left a driver undestroyed.
    DriverRegistry.activeTourCount.value = 0;
  });

  testWidgets(
    'starting a tour hides an already-shown Hints instance; destroying it '
    'brings the beacon back',
    (tester) async {
      final (appContext, hintKey, tourKey) = await _pumpApp(tester);

      var opened = false;
      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: [
            DriverHint(
              element: hintKey,
              id: 'a',
              onOpen: (_, _, _) => opened = true,
            ),
          ],
        ),
      );
      h.show();
      await tester.pumpAndSettle();

      // Sanity: tapping the beacon works before any tour starts.
      await tester.tap(find.byType(HintBeaconWidget));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      h.close();
      await tester.pumpAndSettle();

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(DriveStep(element: tourKey));
      await tester.pumpAndSettle();

      expect(DriverRegistry.activeTourCount.value, greaterThan(0));
      expect(h.isVisible(), isTrue, reason: 'own state is untouched');

      // The beacon is offstage while the tour is up: the default finder
      // (which skips offstage subtrees) no longer finds it, even though it
      // remains mounted with `skipOffstage: false`.
      expect(find.byType(HintBeaconWidget), findsNothing);
      expect(
        find.byType(HintBeaconWidget, skipOffstage: false),
        findsOneWidget,
        reason: 'still mounted — its beacon focus node / state is preserved',
      );

      d.destroy();
      await tester.pumpAndSettle();

      expect(DriverRegistry.activeTourCount.value, 0);

      opened = false;
      await tester.tap(find.byType(HintBeaconWidget));
      await tester.pumpAndSettle();
      expect(opened, isTrue, reason: 'hints reappear once the tour ends');
    },
  );

  testWidgets(
    'two concurrent tours (a tour + a highlight()) both increment/decrement '
    'the same counter; it only reaches zero once both are torn down',
    (tester) async {
      final tourKey = GlobalKey();
      final otherKey = GlobalKey();
      late BuildContext appContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return Stack(
                  children: [
                    SizedBox(key: tourKey, width: 10, height: 10),
                    Positioned(
                      left: 5,
                      top: 5,
                      child: SizedBox(key: otherKey, width: 10, height: 10),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(DriverRegistry.activeTourCount.value, 0);

      final d1 = driver(DriverConfig(animate: false, context: appContext));
      d1.highlight(DriveStep(element: tourKey));
      await tester.pumpAndSettle();
      expect(DriverRegistry.activeTourCount.value, 1);

      final d2 = driver(DriverConfig(animate: false, context: appContext));
      d2.highlight(DriveStep(element: otherKey));
      await tester.pumpAndSettle();
      expect(DriverRegistry.activeTourCount.value, 2);

      d1.destroy();
      await tester.pumpAndSettle();
      expect(
        DriverRegistry.activeTourCount.value,
        1,
        reason: 'still one active driver',
      );

      d2.destroy();
      await tester.pumpAndSettle();
      expect(DriverRegistry.activeTourCount.value, 0);
    },
  );
}
