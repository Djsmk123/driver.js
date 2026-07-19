// Ports `position.test.ts` (the JS reference's pure-geometry test suite for
// `position.ts`) with identical numbers. See
// /Users/smkwinner/Desktop/workspace/drive.js/lib/src/position.dart for the
// already-verified implementation this exercises.

import 'dart:ui';

import 'package:driverjs/src/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveArrowSide', () {
    // Popover box used across these cases.
    const popover = Rect.fromLTRB(600, 100, 800, 400);

    test(
      'keeps the side edge when the element overlaps the popover vertically',
      () {
        const element = Rect.fromLTRB(800, 150, 900, 250);
        expect(resolveArrowSide(Side.left, element, popover), Side.left);
        expect(resolveArrowSide(Side.right, element, popover), Side.right);
      },
    );

    test('points up when a side-placed element scrolls above the popover', () {
      // Element fully above the popover → arrow moves to the top edge (side "bottom").
      const element = Rect.fromLTRB(800, -200, 900, -50);
      expect(resolveArrowSide(Side.left, element, popover), Side.bottom);
      expect(resolveArrowSide(Side.right, element, popover), Side.bottom);
    });

    test('points down when a side-placed element scrolls below the popover', () {
      // Element fully below the popover → arrow moves to the bottom edge (side "top").
      const element = Rect.fromLTRB(800, 500, 900, 600);
      expect(resolveArrowSide(Side.left, element, popover), Side.top);
      expect(resolveArrowSide(Side.right, element, popover), Side.top);
    });

    test(
      'keeps the edge when a top/bottom element overlaps the popover horizontally',
      () {
        const element = Rect.fromLTRB(650, 420, 750, 520);
        expect(resolveArrowSide(Side.top, element, popover), Side.top);
        expect(resolveArrowSide(Side.bottom, element, popover), Side.bottom);
      },
    );

    test(
      'points sideways when a top/bottom element scrolls clear horizontally',
      () {
        const toTheRight = Rect.fromLTRB(900, 420, 1000, 520);
        expect(resolveArrowSide(Side.bottom, toTheRight, popover), Side.left);

        const toTheLeft = Rect.fromLTRB(0, 420, 100, 520);
        expect(resolveArrowSide(Side.bottom, toTheLeft, popover), Side.right);
      },
    );
  });

  group('calculateArrowTarget', () {
    test("aims at the element's center when it sits inside the popover edge", () {
      // Element spans 200..260 (center 230) within a popover spanning 100..400.
      expect(
        calculateArrowTarget(200, 260, 100, 400, PopoverAlignment.start),
        130,
      );
    });

    test(
      'ignores alignment for an element that does not span the whole edge',
      () {
        // Same element; align "end" must not change where it points.
        expect(
          calculateArrowTarget(200, 260, 100, 400, PopoverAlignment.end),
          130,
        );
      },
    );

    test(
      'aims at the center of the overlap when the element runs past one edge',
      () {
        // Element 300..500 against popover 100..400 overlaps on 300..400 → center 350.
        expect(
          calculateArrowTarget(300, 500, 100, 400, PopoverAlignment.center),
          250,
        );
      },
    );

    test(
      'collapses onto the near edge when the element is entirely past the popover',
      () {
        // Entirely below → both endpoints clamp to the popover's far edge.
        expect(
          calculateArrowTarget(500, 600, 100, 400, PopoverAlignment.center),
          300,
        );
        // Entirely above → both clamp to the leading edge.
        expect(
          calculateArrowTarget(-100, -50, 100, 400, PopoverAlignment.center),
          0,
        );
      },
    );

    group('when the element spans the whole popover edge', () {
      // Popover length 300. The element overlaps both ends, so alignment decides.
      test('places the target at the start inset for align: start', () {
        expect(
          calculateArrowTarget(0, 500, 100, 400, PopoverAlignment.start),
          20,
        );
      });

      test('centers the target for align: center', () {
        expect(
          calculateArrowTarget(0, 500, 100, 400, PopoverAlignment.center),
          150,
        );
      });

      test('places the target at the end inset for align: end', () {
        expect(
          calculateArrowTarget(0, 500, 100, 400, PopoverAlignment.end),
          280,
        );
      });
    });
  });

  group('calculateArrowOffset', () {
    test('centers the arrow box on the target', () {
      // Target 130 → box top 125 (arrow box is 10px wide).
      expect(calculateArrowOffset(130, 300), 125);
    });

    test('clamps to the leading corner inset', () {
      expect(calculateArrowOffset(5, 300), 15);
    });

    test('clamps to the trailing corner inset', () {
      expect(calculateArrowOffset(295, 300), 275);
    });

    test('centers the arrow when the popover is too small for the insets', () {
      // length 30 can't honor a 15px inset on both sides → centered: (30-10)/2.
      expect(calculateArrowOffset(20, 30), 10);
    });

    test('never returns a negative offset for a zero-length popover', () {
      expect(calculateArrowOffset(0, 0), 0);
    });
  });
}
