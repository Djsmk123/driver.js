// Widget-level coverage for `hints.dart`'s core lifecycle: mounting/
// unmounting the overlay entry via show()/hide(), missing-element
// skip-and-rescan, single-popover-at-a-time open()/close(), dismiss()
// persistence across hide()/show() (and its clearing by setHints()), and
// the restore()/restoreAll()/isVisible()/getActive()/getHints() accessors.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/hint_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, List<GlobalKey>)> _pumpApp(
  WidgetTester tester,
  List<Rect> rects,
) async {
  final keys = [for (var i = 0; i < rects.length; i++) GlobalKey()];
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return Stack(
              children: [
                for (var i = 0; i < rects.length; i++)
                  Positioned(
                    left: rects[i].left,
                    top: rects[i].top,
                    child: SizedBox(
                      key: keys[i],
                      width: rects[i].width,
                      height: rects[i].height,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  return (appContext, keys);
}

void main() {
  testWidgets('show() mounts beacons, hide() unmounts them', (tester) async {
    final (appContext, keys) = await _pumpApp(tester, [
      const Rect.fromLTWH(50, 50, 40, 40),
    ]);

    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        hints: [DriverHint(element: keys[0])],
      ),
    );

    expect(h.isVisible(), isFalse);
    expect(find.byType(HintBeaconWidget), findsNothing);

    h.show();
    await tester.pumpAndSettle();

    expect(h.isVisible(), isTrue);
    expect(find.byType(HintBeaconWidget), findsOneWidget);

    h.hide();
    await tester.pumpAndSettle();

    expect(h.isVisible(), isFalse);
    expect(find.byType(HintBeaconWidget), findsNothing);
  });

  testWidgets(
    'a hint whose element is missing at show() time is silently skipped, '
    'and picked up the next time show() runs',
    (tester) async {
      final targetKey = GlobalKey();
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
                      left: 10,
                      top: 10,
                      child: SizedBox(key: targetKey, width: 20, height: 20),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final missingKey = GlobalKey();
      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: [
            DriverHint(element: targetKey),
            DriverHint(element: missingKey), // never mounted in the tree
          ],
        ),
      );

      h.show();
      await tester.pumpAndSettle();
      expect(find.byType(HintBeaconWidget), findsOneWidget);

      // The missing hint's element still isn't in the tree — a second
      // show() call re-scans but finds nothing new for it.
      h.show();
      await tester.pumpAndSettle();
      expect(find.byType(HintBeaconWidget), findsOneWidget);
    },
  );

  testWidgets('open(id) shows a popover; opening another closes the first', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester, [
      const Rect.fromLTWH(50, 50, 40, 40),
      const Rect.fromLTWH(200, 200, 40, 40),
    ]);

    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        hints: [
          DriverHint(
            element: keys[0],
            id: 'a',
            popover: const HintPopover(title: 'First'),
          ),
          DriverHint(
            element: keys[1],
            id: 'b',
            popover: const HintPopover(title: 'Second'),
          ),
        ],
      ),
    );

    h.show();
    await tester.pumpAndSettle();

    h.open('a');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    expect(h.getActive()?.id, 'a');

    h.open('b');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(h.getActive()?.id, 'b');

    h.close();
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
    expect(h.getActive(), isNull);
  });

  testWidgets(
    'dismiss(id) hides the beacon and survives hide()->show(); setHints() '
    'clears every dismissal',
    (tester) async {
      final (appContext, keys) = await _pumpApp(tester, [
        const Rect.fromLTWH(50, 50, 40, 40),
      ]);

      final hintList = [DriverHint(element: keys[0], id: 'only')];
      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: hintList,
        ),
      );

      h.show();
      await tester.pumpAndSettle();
      expect(find.byType(HintBeaconWidget), findsOneWidget);

      h.dismiss('only');
      await tester.pumpAndSettle();
      expect(find.byType(HintBeaconWidget), findsNothing);

      h.hide();
      h.show();
      await tester.pumpAndSettle();
      expect(
        find.byType(HintBeaconWidget),
        findsNothing,
        reason: 'dismissal survives a hide()/show() cycle',
      );

      h.setHints(hintList);
      await tester.pumpAndSettle();
      expect(
        find.byType(HintBeaconWidget),
        findsOneWidget,
        reason: 'setHints() clears every prior dismissal',
      );
    },
  );

  testWidgets('restore(id)/restoreAll() undo a dismissal', (tester) async {
    final (appContext, keys) = await _pumpApp(tester, [
      const Rect.fromLTWH(50, 50, 40, 40),
      const Rect.fromLTWH(200, 200, 40, 40),
    ]);

    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        hints: [
          DriverHint(element: keys[0], id: 'a'),
          DriverHint(element: keys[1], id: 'b'),
        ],
      ),
    );

    h.show();
    await tester.pumpAndSettle();
    expect(find.byType(HintBeaconWidget), findsNWidgets(2));

    h.dismiss('a');
    h.dismiss('b');
    await tester.pumpAndSettle();
    expect(find.byType(HintBeaconWidget), findsNothing);

    h.restore('a');
    await tester.pumpAndSettle();
    expect(find.byType(HintBeaconWidget), findsOneWidget);

    h.restoreAll();
    await tester.pumpAndSettle();
    expect(find.byType(HintBeaconWidget), findsNWidgets(2));
  });

  testWidgets('isVisible()/getActive()/getHints() accessors', (tester) async {
    final (appContext, keys) = await _pumpApp(tester, [
      const Rect.fromLTWH(50, 50, 40, 40),
    ]);

    final hintList = [DriverHint(element: keys[0], id: 'a')];
    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        hints: hintList,
      ),
    );

    expect(h.isVisible(), isFalse);
    expect(h.getActive(), isNull);
    expect(h.getHints(), hintList);

    h.show();
    await tester.pumpAndSettle();
    expect(h.isVisible(), isTrue);

    h.open('a');
    await tester.pumpAndSettle();
    expect(h.getActive()?.id, 'a');

    h.hide();
    expect(h.isVisible(), isFalse);
  });
}
