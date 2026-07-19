// Widget-level coverage for M4's `bringInView` (design decision #11):
// skip-if-already-visible, scrolling an off-screen target into view,
// `smoothScroll`'s animated-vs-instant timing, and a hit-test-level
// assertion that `allowScroll: false` doesn't change the dim region's
// already-opaque hit-testing (the documented parity gap — see
// `bringInView`'s doc comment in `lib/src/utils.dart`).

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a `MaterialApp` with a tall, scrolled `SingleChildScrollView` and a
/// single keyed target at [targetIndexFromTop], returning the app's
/// `BuildContext` (for `DriverConfig.context`) plus the list's
/// `ScrollController`, mirroring the harness pattern
/// `driver_navigation_test.dart` uses for its own `_pumpApp`.
///
/// Deliberately a `SingleChildScrollView`/`Column`, not a lazy
/// `ListView.builder`: every item's `RenderBox` needs to actually exist
/// (laid out, even while scrolled off-screen) for `rectOfContext` to
/// resolve it at all — a virtualized list wouldn't have built an
/// off-screen target yet, which would make `DriveStep.element` resolve to
/// `null` and never even attempt a scroll.
Future<(BuildContext, ScrollController)> _pumpList(
  WidgetTester tester,
  GlobalKey targetKey, {
  required int targetIndexFromTop,
}) async {
  final controller = ScrollController();
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  for (var index = 0; index < 50; index++)
                    SizedBox(
                      key: index == targetIndexFromTop ? targetKey : null,
                      height: 60,
                      child: Text('item $index'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  return (appContext, controller);
}

void main() {
  testWidgets(
    'bringInView skips scrolling when the target is already fully visible',
    (tester) async {
      final targetKey = GlobalKey();
      final (appContext, controller) = await _pumpList(
        tester,
        targetKey,
        targetIndexFromTop: 0,
      );

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(DriveStep(element: targetKey));
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    },
  );

  testWidgets('bringInView scrolls an off-screen target into view', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    final (appContext, controller) = await _pumpList(
      tester,
      targetKey,
      targetIndexFromTop: 40,
    );

    final d = driver(DriverConfig(animate: false, context: appContext));
    expect(controller.offset, 0);

    d.highlight(DriveStep(element: targetKey));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets(
    'smoothScroll:true animates the scroll gradually over `duration`',
    (tester) async {
      final targetKey = GlobalKey();
      final (appContext, controller) = await _pumpList(
        tester,
        targetKey,
        targetIndexFromTop: 40,
      );

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          smoothScroll: true,
          duration: const Duration(milliseconds: 400),
        ),
      );

      d.highlight(DriveStep(element: targetKey));
      // Two warm-up pumps: the first builds/inserts the overlay entry, and
      // only the second actually runs `_performHighlight` (which is what
      // starts `bringInView`'s `Scrollable.ensureVisible` animation) — see
      // `_DriverImpl._performHighlight`'s "entry hasn't finished building
      // yet" retry.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final midOffset = controller.offset;

      await tester.pumpAndSettle();
      final finalOffset = controller.offset;

      expect(midOffset, greaterThan(0));
      expect(midOffset, lessThan(finalOffset));
    },
  );

  testWidgets('smoothScroll:false (default) reaches the final offset without a '
      'gradual animation', (tester) async {
    final targetKey = GlobalKey();
    final (appContext, controller) = await _pumpList(
      tester,
      targetKey,
      targetIndexFromTop: 40,
    );

    final d = driver(DriverConfig(animate: false, context: appContext));

    d.highlight(DriveStep(element: targetKey));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final midOffset = controller.offset;

    await tester.pumpAndSettle();
    final finalOffset = controller.offset;

    // Instant jump: already at the final offset well before the 400ms
    // `smoothScroll:true` case above would be.
    expect(midOffset, finalOffset);
  });

  testWidgets(
    "allowScroll: false doesn't change the dim region's opaque hit-testing",
    (tester) async {
      final targetKey = GlobalKey();
      final (appContext, _) = await _pumpList(
        tester,
        targetKey,
        targetIndexFromTop: 0,
      );

      final d = driver(
        DriverConfig(animate: false, context: appContext, allowScroll: false),
      );
      d.highlight(DriveStep(element: targetKey));
      await tester.pumpAndSettle();

      // `allowScroll` isn't wired into `RenderOverlayCutout`'s hit-testing
      // at all (see its doc comment and `bringInView`'s in utils.dart): the
      // dim region is opaque unconditionally, which already absorbs
      // outside-hole interaction regardless of this flag's value. A tap far
      // from the target (bottom-right corner of the default 800x600 test
      // surface, well outside the stage-padding-inflated hole around the
      // target at the top of the list) still lands in the dim region and
      // closes the driver via the default `overlayClickBehavior`.
      await tester.tapAt(const Offset(700, 590));
      await tester.pumpAndSettle();

      expect(d.isActive(), isFalse);
    },
  );
}
