// Coverage for `hint_widgets.dart`'s pure anchor-point math
// (`resolveBeaconAnchorPoint`, exact port of `positionBeacon` in
// `hints.ts`) across a representative sample of the twelve side×align
// combinations plus the offsetX/offsetY nudge, and for `HintBeaconWidget`'s
// pulse animation (running when `animate` resolves true, static when it
// resolves false or `MediaQuery.disableAnimations` is set) and tap-to-toggle
// behavior.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/hint_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveBeaconAnchorPoint', () {
    const element = Rect.fromLTWH(100, 200, 60, 40); // right=160, bottom=240

    test('top + start', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.top,
        align: PopoverAlignment.start,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(100, 200));
    });

    test('top + center', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.top,
        align: PopoverAlignment.center,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(130, 200));
    });

    test('top + end (the default)', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.top,
        align: PopoverAlignment.end,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(160, 200));
    });

    test('bottom + start', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.bottom,
        align: PopoverAlignment.start,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(100, 240));
    });

    test('left + center', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.left,
        align: PopoverAlignment.center,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(100, 220));
    });

    test('right + end', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.right,
        align: PopoverAlignment.end,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(160, 240));
    });

    test('right + start', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.right,
        align: PopoverAlignment.start,
        offsetX: 0,
        offsetY: 0,
      );
      expect(p, const Offset(160, 200));
    });

    test('offsetX/offsetY nudge the resolved point', () {
      final p = resolveBeaconAnchorPoint(
        element: element,
        side: Side.top,
        align: PopoverAlignment.end,
        offsetX: 5,
        offsetY: -8,
      );
      expect(p, const Offset(165, 192));
    });
  });

  group('HintBeaconWidget pulse animation', () {
    Widget wrap(Widget child, {bool disableAnimations = false}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: child),
        ),
      );
    }

    testWidgets('animates when animate resolves true', (tester) async {
      final key = GlobalKey<HintBeaconWidgetState>();
      await tester.pumpWidget(
        wrap(
          HintBeaconWidget(
            key: key,
            style: const HintBeaconStyle(),
            animate: true,
            onTap: () {},
          ),
        ),
      );

      expect(key.currentState!.isAnimating, isTrue);
    });

    testWidgets('static when animate is explicitly false', (tester) async {
      final key = GlobalKey<HintBeaconWidgetState>();
      await tester.pumpWidget(
        wrap(
          HintBeaconWidget(
            key: key,
            style: const HintBeaconStyle(),
            animate: false,
            onTap: () {},
          ),
        ),
      );

      expect(key.currentState!.isAnimating, isFalse);
    });

    testWidgets('static when MediaQuery.disableAnimations is true', (
      tester,
    ) async {
      final key = GlobalKey<HintBeaconWidgetState>();
      await tester.pumpWidget(
        wrap(
          HintBeaconWidget(
            key: key,
            style: const HintBeaconStyle(),
            animate: true, // explicit true still yields to disableAnimations
            onTap: () {},
          ),
          disableAnimations: true,
        ),
      );

      expect(key.currentState!.isAnimating, isFalse);
    });

    testWidgets('tapping the beacon invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          HintBeaconWidget(
            style: const HintBeaconStyle(),
            animate: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(HintBeaconWidget));
      expect(tapped, isTrue);
    });
  });
}
