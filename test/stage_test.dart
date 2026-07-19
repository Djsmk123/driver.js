// Exercises `lib/src/stage.dart` (already-written and verified — see that
// file's header). Ports the intent of `stage.test.ts` (radius clamp,
// padding growth) plus a `Path.contains` dim-vs-hole check, since Dart's
// `Path` gives us a direct oracle the JS test (which only asserts against
// the generated SVG path *string*) doesn't have.

import 'dart:ui';

import 'package:driverjs/src/stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inflateStage', () {
    test('grows the target rect by padding on every side', () {
      const target = Rect.fromLTWH(100, 100, 200, 50);
      final grown = inflateStage(target, 10);
      expect(grown, const Rect.fromLTWH(90, 90, 220, 70));
    });

    test('zero padding is a no-op', () {
      const target = Rect.fromLTWH(100, 100, 200, 50);
      expect(inflateStage(target, 0), target);
    });
  });

  group('clampStageRadius', () {
    test(
      'clamps a radius larger than half the stage to half the smaller dimension',
      () {
        // A tiny 10x10 stage can't fit a 20px radius; half of 10 is 5.
        expect(clampStageRadius(20, 10, 10), 5);
      },
    );

    test('floors a negative radius at zero', () {
      expect(clampStageRadius(-5, 200, 50), 0);
    });

    test('leaves a radius that already fits untouched (modulo flooring)', () {
      expect(clampStageRadius(5, 200, 50), 5);
    });

    test('floors a fractional clamp result', () {
      // half of 11 is 5.5 -> floored to 5.
      expect(clampStageRadius(20, 11, 11), 5);
    });
  });

  group('buildStagePath dim/hole hit-testing', () {
    const screenSize = Size(400, 300);
    const target = Rect.fromLTWH(150, 100, 100, 50);

    test('contains points in the dim region (outside the stage)', () {
      final path = buildStagePath(
        screenSize: screenSize,
        target: target,
        padding: 0,
        radius: 0,
      );
      expect(path.contains(const Offset(5, 5)), isTrue);
      expect(path.contains(const Offset(395, 295)), isTrue);
    });

    test('excludes points inside the stage hole', () {
      final path = buildStagePath(
        screenSize: screenSize,
        target: target,
        padding: 0,
        radius: 0,
      );
      // Center of the target rect.
      expect(path.contains(const Offset(200, 125)), isFalse);
    });

    test(
      'padding grows the hole so a point just outside the raw target is still excluded',
      () {
        final path = buildStagePath(
          screenSize: screenSize,
          target: target,
          padding: 10,
          radius: 0,
        );
        // 5px outside the raw target's left edge, but inside the 10px padding.
        expect(path.contains(const Offset(145, 125)), isFalse);
      },
    );

    test('without padding, that same point is in the dim region', () {
      final path = buildStagePath(
        screenSize: screenSize,
        target: target,
        padding: 0,
        radius: 0,
      );
      expect(path.contains(const Offset(145, 125)), isTrue);
    });
  });
}
