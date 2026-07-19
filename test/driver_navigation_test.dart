// Widget-level coverage for `driver.dart`'s tour navigation: `drive()`,
// `moveNext`/`movePrevious`/`moveTo` (including past-either-end destroy),
// `getPreviousStep`/`getPreviousElement` reflecting *visit history* rather
// than `index - 1`, `setConfig`'s wholesale-replace semantics, and
// `setSteps` resetting navigation state while keeping the rest of the
// config.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a `MaterialApp` with three positioned, keyed targets and returns
/// the app's `BuildContext` (for `DriverConfig.context`) plus the three
/// `GlobalKey`s, mirroring the harness pattern `overlay_widget_test.dart`
/// and `popover_widget_test.dart` already use.
Future<(BuildContext, List<GlobalKey>)> _pumpApp(WidgetTester tester) async {
  final keys = List.generate(3, (_) => GlobalKey());
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
                    left: 20.0 * i,
                    top: 20.0 * i,
                    child: SizedBox(
                      key: keys[i],
                      width: 40,
                      height: 20,
                      child: ColoredBox(color: Colors.primaries[i]),
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
  testWidgets('drive() with no arg starts at step 0', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive();
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 0);
    expect(d.getActiveElement(), keys[0].currentContext);
  });

  testWidgets('drive(index) starts at an arbitrary in-range step', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive(1);
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 1);
  });

  testWidgets('drive() with no steps configured destroys immediately', (
    tester,
  ) async {
    final (appContext, _) = await _pumpApp(tester);
    final d = driver(DriverConfig(animate: false, context: appContext));

    d.drive();
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets('drive(outOfRange) destroys instead of throwing', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [DriveStep(element: keys[0])],
      ),
    );

    d.drive(5);
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets('moveNext()/movePrevious() walk the tour', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 0);

    d.moveNext();
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 1);

    d.moveNext();
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 2);

    d.movePrevious();
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 1);
  });

  testWidgets('moveNext() past the last step destroys the driver', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester);
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

    d.drive(1);
    await tester.pumpAndSettle();
    expect(d.isActive(), isTrue);

    d.moveNext();
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets(
    'movePrevious() on the first step destroys the driver (unlike the '
    'keyboard-only ArrowLeft no-op guard)',
    (tester) async {
      final (appContext, keys) = await _pumpApp(tester);
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
      expect(d.isActive(), isTrue);

      d.movePrevious();
      await tester.pumpAndSettle();

      expect(d.isActive(), isFalse);
    },
  );

  testWidgets('moveTo(outOfRange) destroys the driver', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
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

    d.moveTo(9);
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets('moveTo(inRange) jumps straight to that step', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    d.moveTo(2);
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 2);
  });

  testWidgets(
    'getPreviousStep()/getPreviousElement() reflect visit history, not '
    'index - 1',
    (tester) async {
      final (appContext, keys) = await _pumpApp(tester);
      final steps = [for (final key in keys) DriveStep(element: key)];
      final d = driver(
        DriverConfig(animate: false, context: appContext, steps: steps),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      // Jump straight from step 0 to step 2 — if `getPreviousStep` were
      // just `index - 1`, it would (wrongly) point at step 1, which was
      // never actually visited.
      d.moveTo(2);
      await tester.pumpAndSettle();

      // `getPreviousStep()` returns the *resolved* tour step (button/text
      // quirks baked in by `resolveTourStep`), not the same object identity
      // as the original `steps[0]` — compare by its `element` instead.
      expect(d.getPreviousStep()?.element, keys[0]);
      expect(d.getPreviousElement(), keys[0].currentContext);
      expect(d.getActiveIndex(), 2);
    },
  );

  testWidgets('setConfig replaces the config wholesale, not merged', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester);
    final steps = [DriveStep(element: keys[0])];
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: steps,
        allowClose: false,
        duration: const Duration(milliseconds: 999),
      ),
    );

    expect(d.getConfig().allowClose, isFalse);
    expect(d.getConfig().duration, const Duration(milliseconds: 999));

    // A fresh config that doesn't repeat `allowClose`/`duration` at all —
    // wholesale replace means both fall back to `DriverConfig`'s own
    // defaults rather than carrying the old values forward.
    d.setConfig(DriverConfig(context: appContext, steps: steps));

    expect(d.getConfig().allowClose, isTrue);
    expect(d.getConfig().duration, const Duration(milliseconds: 400));
  });

  testWidgets('setSteps resets navigation state but keeps the rest of '
      'the config', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final originalSteps = [for (final key in keys) DriveStep(element: key)];
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: originalSteps,
        stagePadding: 42,
      ),
    );

    d.drive(1);
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 1);

    final newSteps = [DriveStep(element: keys[0])];
    d.setSteps(newSteps);

    expect(d.getActiveIndex(), isNull);
    expect(d.getConfig().steps, newSteps);
    // Everything else on the config survives the steps-only replacement.
    expect(d.getConfig().stagePadding, 42);
  });
}
