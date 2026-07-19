// Coverage for the hint popover: `resolveHintPopoverPosition`'s pure
// anchor-to-beacon (normal mode, padding working out to 10 with the
// defaults) vs. anchor-to-element (overlay mode) math, the beacon hiding
// itself while its own popover is open in overlay mode, the
// `buttonText` fallback chain (hint -> config -> 'Got it'),
// `onButtonClick` replacing the default dismiss-on-click, and
// `onPopoverRender` mutating the rendered popover.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/hint_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, GlobalKey)> _pumpApp(
  WidgetTester tester,
  Rect rect,
) async {
  final key = GlobalKey();
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
                  left: rect.left,
                  top: rect.top,
                  child: SizedBox(
                    key: key,
                    width: rect.width,
                    height: rect.height,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  return (appContext, key);
}

void main() {
  group('resolveHintPopoverPosition (pure)', () {
    test('normal mode anchors to the beacon point with padding 10', () {
      const elementRect = Rect.fromLTWH(0, 0, 100, 100);
      const beaconPoint = Offset(50, 0); // top+center anchor, say
      final position = resolveHintPopoverPosition(
        popover: const HintPopover(),
        elementRect: elementRect,
        beaconPoint: beaconPoint,
        beaconSize: 24, // the default HintBeaconStyle.size
        popoverOffset: 10, // the default HintsConfig.popoverOffset
        overlay: false,
      );

      // anchor is a near-zero rect centered exactly on the beacon point.
      expect(position.anchor.center, beaconPoint);
      expect(position.anchor.width, 0);
      expect(position.anchor.height, 0);
      // padding = (15 + 14/2) - 24/2 = 22 - 12 = 10, per the plan.
      expect(position.padding, 10);
      expect(position.offset, 10);
      expect(position.side, Side.bottom); // HintPopover default
      expect(position.align, PopoverAlignment.start); // HintPopover default
    });

    test('overlay mode anchors to the real element rect', () {
      const elementRect = Rect.fromLTWH(10, 20, 100, 50);
      final position = resolveHintPopoverPosition(
        popover: const HintPopover(),
        elementRect: elementRect,
        beaconPoint: const Offset(60, 20),
        beaconSize: 24,
        popoverOffset: 10,
        overlay: true,
      );

      expect(position.anchor, elementRect);
      expect(position.padding, 10); // kHintOverlayPadding
      expect(position.offset, 20); // kHintOverlayPadding + popoverOffset
    });

    test('a smaller beacon shifts the normal-mode padding accordingly', () {
      final position = resolveHintPopoverPosition(
        popover: const HintPopover(),
        elementRect: const Rect.fromLTWH(0, 0, 10, 10),
        beaconPoint: Offset.zero,
        beaconSize: 12,
        popoverOffset: 10,
        overlay: false,
      );
      // (15 + 7) - 6 = 16
      expect(position.padding, 16);
    });
  });

  group('hint popover widget behavior', () {
    testWidgets(
      'overlay mode anchors the popover to the element and hides the beacon '
      'while it is open',
      (tester) async {
        final (appContext, key) = await _pumpApp(
          tester,
          const Rect.fromLTWH(50, 50, 40, 40),
        );

        final h = hints(
          HintsConfig(
            beacon: const HintBeacon(animate: false),
            context: appContext,
            overlay: true,
            hints: [
              DriverHint(
                element: key,
                id: 'a',
                popover: const HintPopover(title: 'Overlay hint'),
              ),
            ],
          ),
        );

        h.show();
        await tester.pumpAndSettle();
        expect(find.byType(HintBeaconWidget), findsOneWidget);

        h.open('a');
        await tester.pumpAndSettle();

        expect(find.text('Overlay hint'), findsOneWidget);
        expect(
          find.byType(HintBeaconWidget),
          findsNothing,
          reason: 'overlay mode hides the beacon while its popover is open',
        );

        h.close();
        await tester.pumpAndSettle();
        expect(
          find.byType(HintBeaconWidget),
          findsOneWidget,
          reason: 'closing brings the beacon back',
        );
      },
    );

    testWidgets('buttonText fallback chain: hint -> config -> Got it', (
      tester,
    ) async {
      final (appContext, key) = await _pumpApp(
        tester,
        const Rect.fromLTWH(50, 50, 40, 40),
      );

      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: [DriverHint(element: key, id: 'default')],
        ),
      );
      h.show();
      await tester.pumpAndSettle();
      h.open('default');
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsOneWidget);
      h.hide();
      await tester.pumpAndSettle();

      final h2 = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          buttonText: 'Config default',
          hints: [DriverHint(element: key, id: 'cfg')],
        ),
      );
      h2.show();
      await tester.pumpAndSettle();
      h2.open('cfg');
      await tester.pumpAndSettle();
      expect(find.text('Config default'), findsOneWidget);
      h2.hide();
      await tester.pumpAndSettle();

      final h3 = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          buttonText: 'Config default',
          hints: [
            DriverHint(
              element: key,
              id: 'hint',
              popover: const HintPopover(buttonText: 'Hint wins'),
            ),
          ],
        ),
      );
      h3.show();
      await tester.pumpAndSettle();
      h3.open('hint');
      await tester.pumpAndSettle();
      expect(find.text('Hint wins'), findsOneWidget);
    });

    testWidgets(
      'onButtonClick replaces the default dismiss-on-click behavior',
      (tester) async {
        final (appContext, key) = await _pumpApp(
          tester,
          const Rect.fromLTWH(50, 50, 40, 40),
        );

        var clicked = false;
        final h = hints(
          HintsConfig(
            beacon: const HintBeacon(animate: false),
            context: appContext,
            hints: [
              DriverHint(
                element: key,
                id: 'a',
                popover: HintPopover(
                  buttonText: 'Click me',
                  onButtonClick: (element, hint, opts) => clicked = true,
                ),
              ),
            ],
          ),
        );

        h.show();
        await tester.pumpAndSettle();
        h.open('a');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Click me'));
        await tester.pumpAndSettle();

        expect(clicked, isTrue);
        // Not dismissed automatically — onButtonClick replaces, doesn't
        // chain to, the default dismiss.
        expect(find.byType(HintBeaconWidget), findsOneWidget);
        expect(h.getActive()?.id, 'a');
      },
    );

    testWidgets('onPopoverRender can mutate the rendered popover data', (
      tester,
    ) async {
      final (appContext, key) = await _pumpApp(
        tester,
        const Rect.fromLTWH(50, 50, 40, 40),
      );

      final h = hints(
        HintsConfig(
          beacon: const HintBeacon(animate: false),
          context: appContext,
          hints: [
            DriverHint(
              element: key,
              id: 'a',
              popover: HintPopover(
                title: 'Original',
                onPopoverRender: (data, opts) {
                  data.title = 'Mutated';
                },
              ),
            ),
          ],
        ),
      );

      h.show();
      await tester.pumpAndSettle();
      h.open('a');
      await tester.pumpAndSettle();

      expect(find.text('Mutated'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
    });
  });
}
