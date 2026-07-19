// Coverage for hints' Escape/outside-tap/overlay-dim-tap close paths:
// Escape closes the open popover and returns focus to its beacon;
// non-overlay-mode outside taps close the popover without swallowing the
// tap for anything else underneath; overlay-mode dim taps close the
// popover too.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/hint_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Escape closes the open popover and refocuses its beacon', (
    tester,
  ) async {
    final hintKey = GlobalKey();
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
                    left: 50,
                    top: 50,
                    child: SizedBox(key: hintKey, width: 30, height: 30),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        hints: [
          DriverHint(
            element: hintKey,
            id: 'a',
            popover: const HintPopover(title: 'Hint title'),
          ),
        ],
      ),
    );
    h.show();
    await tester.pumpAndSettle();

    h.open('a');
    await tester.pumpAndSettle();
    expect(find.text('Hint title'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Hint title'), findsNothing);
    expect(h.getActive(), isNull);

    // Focus returned to the beacon.
    final beaconFocus = Focus.of(tester.element(find.byType(HintBeaconWidget)));
    expect(beaconFocus.hasFocus, isTrue);
  });

  testWidgets(
    'a non-overlay-mode outside tap closes the popover without swallowing '
    'the tap for the underlying app',
    (tester) async {
      final hintKey = GlobalKey();
      late BuildContext appContext;
      var backgroundTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => backgroundTapped = true,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 50,
                      child: SizedBox(key: hintKey, width: 30, height: 30),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: [
            DriverHint(
              element: hintKey,
              id: 'a',
              popover: const HintPopover(title: 'Hint title'),
            ),
          ],
        ),
      );
      h.show();
      await tester.pumpAndSettle();
      h.open('a');
      await tester.pumpAndSettle();
      expect(find.text('Hint title'), findsOneWidget);

      // Tap far away from the beacon/popover — an "outside" tap.
      await tester.tapAt(const Offset(500, 500));
      await tester.pumpAndSettle();

      expect(find.text('Hint title'), findsNothing);
      expect(
        backgroundTapped,
        isTrue,
        reason:
            'the outside-tap catcher is translucent — it never blocks the '
            'app underneath',
      );
    },
  );

  testWidgets('overlay-mode dim tap closes the open popover', (tester) async {
    final hintKey = GlobalKey();
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
                    left: 50,
                    top: 50,
                    child: SizedBox(key: hintKey, width: 30, height: 30),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final h = hints(
      HintsConfig(
        beacon: const HintBeacon(animate: false),
        context: appContext,
        overlay: true,
        hints: [
          DriverHint(
            element: hintKey,
            id: 'a',
            popover: const HintPopover(title: 'Overlay title'),
          ),
        ],
      ),
    );
    h.show();
    await tester.pumpAndSettle();
    h.open('a');
    await tester.pumpAndSettle();
    expect(find.text('Overlay title'), findsOneWidget);

    // Tap far from the cutout — lands on the dim.
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();

    expect(find.text('Overlay title'), findsNothing);
    expect(h.getActive(), isNull);
  });
}
