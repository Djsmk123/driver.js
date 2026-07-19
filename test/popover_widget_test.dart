// Widget-level coverage for M2's popover: `RenderPopoverPositioner` actually
// landing where `position.dart`'s already-verified `resolvePopoverPlacement`
// (see position_test.dart) says it should, plus the default content
// widget's button/text/hook wiring and the halfway-delayed render timing
// from design decision #3.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/position.dart' show resolvePopoverPlacement;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a bare [PopoverPositioner] with a fixed-size child at
/// [contentSize], inside a viewport resized to [overlaySize], and returns
/// its render object so a test can inspect
/// [RenderPopoverPositioner.placement].
///
/// This bypasses `Driver`/`highlight()` entirely — the positioner's inputs
/// (`element`, `side`, `align`, …) are exactly `resolvePopoverPlacement`'s
/// parameters, so pumping it directly lets these tests assert the *widget*
/// lands wherever the pure math (already unit-tested) says it should,
/// without needing a real highlighted element to derive a rect from.
///
/// [overlaySize] is applied by resizing `tester.view` rather than wrapping
/// in a `SizedBox`: `pumpWidget` gives the root widget *tight* constraints
/// matching the test viewport (the default 800x600), and a `SizedBox`
/// can't shrink a subtree below a tight incoming constraint — only
/// widening the actual viewport changes what "the overlay's size" means
/// here, exactly like [RenderPopoverPositioner.sizedByParent] taking
/// `constraints.biggest` from whatever's above it in the real overlay.
Future<RenderPopoverPositioner> pumpPositioner(
  WidgetTester tester, {
  required Rect element,
  required Side side,
  PopoverAlignment align = PopoverAlignment.start,
  double offset = 20,
  double padding = 10,
  bool centered = false,
  Size overlaySize = const Size(800, 600),
  Size contentSize = const Size(250, 120),
}) async {
  tester.view.physicalSize = overlaySize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: PopoverPositioner(
        element: element,
        side: side,
        align: align,
        offset: offset,
        padding: padding,
        centered: centered,
        arrowColor: const Color(0xFFFFFFFF),
        child: SizedBox(width: contentSize.width, height: contentSize.height),
      ),
    ),
  );
  return tester.renderObject<RenderPopoverPositioner>(
    find.byType(PopoverPositioner),
  );
}

void main() {
  group('RenderPopoverPositioner placement', () {
    const overlaySize = Size(800, 600);
    const contentSize = Size(250, 120);
    // Comfortably inside the overlay on every side, so whichever side is
    // requested has room and wins outright.
    const centeredElement = Rect.fromLTWH(375, 275, 50, 50);

    for (final side in Side.values) {
      for (final align in PopoverAlignment.values) {
        testWidgets(
          'renders on the requested side ($side, $align) when it has room',
          (tester) async {
            final expected = resolvePopoverPlacement(
              element: centeredElement,
              popoverSize: contentSize,
              overlaySize: overlaySize,
              side: side,
              align: align,
              offset: 20,
              padding: 10,
            );

            final render = await pumpPositioner(
              tester,
              element: centeredElement,
              side: side,
              align: align,
              overlaySize: overlaySize,
              contentSize: contentSize,
            );

            expect(render.placement!.offset, expected.offset);
            expect(render.placement!.renderedSide, expected.renderedSide);
            expect(render.placement!.arrowSide, expected.arrowSide);
            expect(render.placement!.arrowOffset, expected.arrowOffset);
            // Every side had room, so the preferred side is exactly what
            // rendered — the fallback chain never kicked in.
            expect(render.placement!.renderedSide, side);
          },
        );
      }
    }

    testWidgets(
      'falls back to another side when the preferred one has no room',
      (tester) async {
        // Pinned to the very top-left corner: requesting `top` (no room
        // above) or `left` (no room to the left) must fall back.
        const element = Rect.fromLTWH(5, 5, 50, 50);

        final expected = resolvePopoverPlacement(
          element: element,
          popoverSize: contentSize,
          overlaySize: overlaySize,
          side: Side.top,
          align: PopoverAlignment.start,
          offset: 20,
          padding: 10,
        );
        // Ground truth from the pure math: `top` has no room, so the
        // left→right→top→bottom fallback chain picks the next side that
        // does.
        expect(expected.renderedSide, isNot(Side.top));

        final render = await pumpPositioner(
          tester,
          element: element,
          side: Side.top,
          overlaySize: overlaySize,
          contentSize: contentSize,
        );

        expect(render.placement!.renderedSide, expected.renderedSide);
        expect(render.placement!.offset, expected.offset);
      },
    );

    testWidgets(
      'centered (element-less) popover has no arrow and sits in the middle',
      (tester) async {
        final render = await pumpPositioner(
          tester,
          // A zero-size point at the overlay's center, mirroring the
          // element-less "dummy" rect `highlight.dart` builds.
          element: const Rect.fromLTWH(400, 300, 0, 0),
          side: Side.bottom,
          centered: true,
          overlaySize: overlaySize,
          contentSize: contentSize,
        );

        final placement = render.placement!;
        expect(placement.renderedSide, isNull);
        expect(placement.arrowSide, isNull);
        expect(placement.arrowOffset, isNull);
        expect(
          placement.offset,
          Offset(
            overlaySize.width / 2 - contentSize.width / 2,
            overlaySize.height / 2 - contentSize.height / 2,
          ),
        );
      },
    );

    testWidgets('pins to the bottom with no arrow when no side has room', (
      tester,
    ) async {
      // A tiny overlay with a huge element leaves no side with room on
      // any edge — every `is*Optimal` check fails.
      const tinyOverlay = Size(60, 60);
      const hugeElement = Rect.fromLTWH(-500, -500, 2000, 2000);

      final render = await pumpPositioner(
        tester,
        element: hugeElement,
        side: Side.bottom,
        overlaySize: tinyOverlay,
        contentSize: contentSize,
      );

      // The requested `contentSize` (250x120) doesn't fit the width band
      // `min(300, overlayWidth - 2*arrowSize)` imposes on a 60px-wide
      // overlay, so the child was clamped narrower than requested — read
      // back its *actual* laid-out size rather than assuming `contentSize`
      // survived, then use that as the ground truth's `popoverSize`.
      final actualSize = render.child!.size;
      final expected = resolvePopoverPlacement(
        element: hugeElement,
        popoverSize: actualSize,
        overlaySize: tinyOverlay,
        side: Side.bottom,
        align: PopoverAlignment.start,
        offset: 20,
        padding: 10,
      );
      expect(expected.renderedSide, isNull);

      final placement = render.placement!;
      expect(placement.renderedSide, isNull);
      expect(placement.arrowSide, isNull);
      expect(placement.offset, expected.offset);
    });

    testWidgets(
      'the arrow flips to the perpendicular edge when the element scrolls '
      'past a left-placed popover',
      (tester) async {
        // `element.left` (350) leaves comfortable room for a 250-wide
        // popover plus the 20px offset to its left, so `left` is still the
        // rendered side — but the element sits far above the popover's
        // vertical span, so `resolveArrowSide` (already unit-tested in
        // position_test.dart) moves the arrow from the left edge to the
        // bottom edge (pointing down) instead of sliding into the corner.
        const element = Rect.fromLTWH(350, -400, 50, 50);

        final expected = resolvePopoverPlacement(
          element: element,
          popoverSize: contentSize,
          overlaySize: overlaySize,
          side: Side.left,
          align: PopoverAlignment.start,
          offset: 20,
          padding: 10,
        );
        expect(expected.renderedSide, Side.left);
        expect(expected.arrowSide, isNot(Side.left));

        final render = await pumpPositioner(
          tester,
          element: element,
          side: Side.left,
          overlaySize: overlaySize,
          contentSize: contentSize,
        );

        expect(render.placement!.renderedSide, Side.left);
        expect(render.placement!.arrowSide, expected.arrowSide);
      },
    );
  });

  group('DriverPopoverContent (through Driver.highlight)', () {
    Future<BuildContext> pumpApp(
      WidgetTester tester, {
      required GlobalKey key1,
      required GlobalKey key2,
    }) async {
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
                      child: SizedBox(key: key1, width: 40, height: 40),
                    ),
                    Positioned(
                      right: 50,
                      bottom: 50,
                      child: SizedBox(key: key2, width: 40, height: 40),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      return appContext;
    }

    testWidgets('renders default title/description/buttons', (tester) async {
      final key = GlobalKey();
      final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(
        DriveStep(
          element: key,
          popover: const DriverPopover(
            title: 'A Title',
            description: 'A description',
            // `Driver.highlight()` defaults a bare popover to buttonless
            // (design decision #6) — set explicitly since this test is
            // about the button *widgets* rendering, not that default.
            showButtons: [
              DriverButton.next,
              DriverButton.previous,
              DriverButton.close,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Title'), findsOneWidget);
      expect(find.text('A description'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
    });

    testWidgets('showButtons hides buttons not listed', (tester) async {
      final key = GlobalKey();
      final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(
        DriveStep(
          element: key,
          popover: const DriverPopover(
            title: 'T',
            showButtons: [DriverButton.next],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('×'), findsNothing);
    });

    testWidgets('disableButtons swallows taps on the disabled button', (
      tester,
    ) async {
      final key = GlobalKey();
      final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

      var nextClicked = false;
      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(
        DriveStep(
          element: key,
          popover: DriverPopover(
            title: 'T',
            showButtons: const [DriverButton.next],
            disableButtons: const [DriverButton.next],
            onNextClick: (_, _, _) => nextClicked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `warnIfMissed: false`: the disabled button is wrapped in an
      // `IgnorePointer`, so the tap deliberately doesn't hit-test anything
      // — that's exactly the behavior under test.
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(nextClicked, isFalse);
    });

    testWidgets('a Widget-override text slot wins over its String twin', (
      tester,
    ) async {
      final key = GlobalKey();
      final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(
        DriveStep(
          element: key,
          popover: const DriverPopover(
            title: 'Ignored title',
            titleWidget: Text('Widget title wins'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Widget title wins'), findsOneWidget);
      expect(find.text('Ignored title'), findsNothing);
    });

    testWidgets(
      'onPopoverRender can mutate DriverPopoverData before it renders',
      (tester) async {
        final key = GlobalKey();
        final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

        final d = driver(DriverConfig(animate: false, context: appContext));
        d.highlight(
          DriveStep(
            element: key,
            popover: DriverPopover(
              title: 'Original',
              onPopoverRender: (data, opts) {
                data.title = 'Mutated by hook';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mutated by hook'), findsOneWidget);
        expect(find.text('Original'), findsNothing);
      },
    );

    testWidgets(
      'popoverBuilder fully replaces content while the positioner/arrow '
      'still apply',
      (tester) async {
        final key = GlobalKey();
        final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

        final d = driver(DriverConfig(animate: false, context: appContext));
        d.highlight(
          DriveStep(
            element: key,
            popover: DriverPopover(
              title: 'Not shown',
              popoverBuilder: (data, opts) => const SizedBox(
                width: 260,
                height: 80,
                child: Text('Fully custom content'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fully custom content'), findsOneWidget);
        expect(find.text('Not shown'), findsNothing);
        // The positioner (and thus arrow placement) still wraps the
        // custom content — the builder only swaps what's inside it.
        final render = tester.renderObject<RenderPopoverPositioner>(
          find.byType(PopoverPositioner),
        );
        expect(render.placement, isNotNull);
      },
    );

    testWidgets(
      'extraFooterChildren appended by onPopoverRender show up in the footer',
      (tester) async {
        final key = GlobalKey();
        final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

        final d = driver(DriverConfig(animate: false, context: appContext));
        d.highlight(
          DriveStep(
            element: key,
            popover: DriverPopover(
              title: 'T',
              // The footer (where `extraFooterChildren` render) only
              // builds when at least one button or progress shows —
              // `Driver.highlight()` otherwise defaults to buttonless
              // (design decision #6).
              showButtons: const [DriverButton.next],
              onPopoverRender: (data, opts) {
                // Short text: the footer row (progress + prev/next +
                // extras) isn't scrollable/wrapped, matching popover.css's
                // single-line footer, so a long extra label would overflow
                // the 250-300px popover body — not what this test is
                // about.
                data.extraFooterChildren = [const Text('Extra')];
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Extra'), findsOneWidget);
      },
    );

    testWidgets(
      'a non-first animated highlight delays the popover render to the '
      "animation's halfway point",
      (tester) async {
        final key1 = GlobalKey();
        final key2 = GlobalKey();
        final appContext = await pumpApp(tester, key1: key1, key2: key2);

        const duration = Duration(milliseconds: 400);
        final d = driver(DriverConfig(context: appContext, duration: duration));

        d.highlight(
          DriveStep(
            element: key1,
            popover: const DriverPopover(title: 'First'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);

        d.highlight(
          DriveStep(
            element: key2,
            popover: const DriverPopover(title: 'Second'),
          ),
        );
        // First pump runs the deferred `_performHighlight` postFrameCallback
        // — which calls `hidePopover()` and starts the (animated,
        // non-first) stage ticker — but a `setState` made from *inside* a
        // postFrameCallback lands after that frame already painted, so it
        // takes a second, zero-duration pump to actually flush the
        // resulting rebuild (unlike the ticker-driven halfway render
        // below, which fires as a transient callback *before* its frame's
        // build phase and so is visible within the same pump).
        await tester.pump();
        await tester.pump();
        expect(find.text('First'), findsNothing);
        expect(find.text('Second'), findsNothing);

        // Advance to exactly the halfway point.
        await tester.pump(duration ~/ 2);
        expect(find.text('Second'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
      },
    );

    testWidgets(
      'the very first highlight renders its popover immediately, even '
      'when animated',
      (tester) async {
        final key = GlobalKey();
        final appContext = await pumpApp(tester, key1: key, key2: GlobalKey());

        final d = driver(
          DriverConfig(
            context: appContext,
            duration: const Duration(milliseconds: 400),
          ),
        );
        d.highlight(
          DriveStep(
            element: key,
            popover: const DriverPopover(title: 'Immediate'),
          ),
        );

        // No prior highlight means `isFirstHighlight` is true, so the
        // popover isn't delayed to the halfway point — but (as above) its
        // `showPopover` call still happens inside a postFrameCallback, so
        // a second pump is needed to see the resulting rebuild painted.
        await tester.pump();
        await tester.pump();
        expect(find.text('Immediate'), findsOneWidget);
      },
    );
  });
}
