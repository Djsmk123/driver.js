// Widget-level coverage for `overlay_widget.dart`/`driver.dart`'s keyboard
// handling and focus trap (design decision #10 in the plan): Escape/
// ArrowRight/ArrowLeft routing, `allowKeyboardControl: false` disabling all
// of it, ArrowLeft no-oping on the first step, every key no-oping while a
// highlight transition is mid-flight, and the popover's Tab focus trap
// staying confined to its own controls.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
                    child: SizedBox(key: keys[i], width: 40, height: 20),
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

/// Whether whatever currently has focus lives inside the popover's own
/// content widget — used to assert the Tab trap never lets focus escape
/// onto the app content behind the overlay.
bool _focusIsInsidePopover() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<DriverPopoverContent>() != null;
}

void main() {
  testWidgets('Escape closes the driver when allowClose is true', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [DriveStep(element: keys[0])],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();
    expect(d.isActive(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets('Escape does nothing when allowClose is false', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        allowClose: false,
        steps: [DriveStep(element: keys[0])],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(d.isActive(), isTrue);
  });

  testWidgets('ArrowRight advances to the next step', (tester) async {
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 1);
  });

  testWidgets('ArrowLeft moves back a step when not on the first one', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 0);
  });

  testWidgets(
    'ArrowLeft no-ops on the first step (unlike movePrevious(), which '
    'destroys)',
    (tester) async {
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

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(d.isActive(), isTrue);
      expect(d.getActiveIndex(), 0);
    },
  );

  testWidgets('allowKeyboardControl: false disables every key', (tester) async {
    final (appContext, keys) = await _pumpApp(tester);
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        allowKeyboardControl: false,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(d.isActive(), isTrue);
  });

  testWidgets('every key no-ops while a highlight transition is mid-flight', (
    tester,
  ) async {
    final (appContext, keys) = await _pumpApp(tester);
    const duration = Duration(milliseconds: 400);
    final d = driver(
      DriverConfig(
        context: appContext,
        duration: duration,
        steps: [for (final key in keys) DriveStep(element: key)],
      ),
    );

    d.drive(0);
    // Only pump partway through the transition — the stage-chase ticker
    // (and `DriverState.transitionToken`, which the keyboard handlers
    // check) is still mid-flight here.
    await tester.pump();
    await tester.pump(duration ~/ 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Still on step 0 — the key press landed mid-transition and was
    // dropped, not queued.
    expect(d.getActiveIndex(), 0);

    await tester.pumpAndSettle();

    // Once the transition settles, the same key works normally.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 1);
  });

  testWidgets(
    'the popover autofocuses a control on render and Tab cycling stays '
    "confined to the popover's own controls",
    (tester) async {
      final (appContext, keys) = await _pumpApp(tester);
      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(
              element: keys[0],
              popover: const DriverPopover(
                title: 'Step',
                showButtons: [
                  DriverButton.previous,
                  DriverButton.next,
                  DriverButton.close,
                ],
              ),
            ),
          ],
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      expect(
        _focusIsInsidePopover(),
        isTrue,
        reason: 'a focusable popover control should autofocus on render',
      );

      // More presses than there are focusable controls, so a trap that
      // leaked would definitely have escaped by now.
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusIsInsidePopover(), isTrue);
      }
    },
  );
}
