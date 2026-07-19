// Exercises `easeInOutQuadJs`/`EaseInOutQuadCurve` in lib/src/utils.dart
// against hand-computed values from the exact JS polynomial in utils.ts
// (`easeInOutQuad`), NOT Flutter's `Curves.easeInOutQuad` (which is a
// different, cubic, curve and would not match these numbers).

import 'package:driverjs/src/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('easeInOutQuadJs', () {
    test('returns the initial value at elapsed 0', () {
      expect(easeInOutQuadJs(0, 0, 100, 400), 0);
    });

    test('returns initialValue + amountOfChange at elapsed == duration', () {
      expect(easeInOutQuadJs(400, 0, 100, 400), 100);
    });

    test('is exactly halfway at elapsed == duration / 2', () {
      expect(easeInOutQuadJs(200, 0, 100, 400), 50);
    });

    test('accelerates through the first quarter (quadratic ease-in half)', () {
      // t = 100/200 = 0.5 -> (100/2) * 0.5 * 0.5 = 12.5
      expect(easeInOutQuadJs(100, 0, 100, 400), 12.5);
    });

    test('decelerates through the last quarter (quadratic ease-out half)', () {
      // t = 300/200 = 1.5 -> t' = 0.5 -> -(100/2) * (0.5*(0.5-2) - 1) = 87.5
      expect(easeInOutQuadJs(300, 0, 100, 400), 87.5);
    });

    test('offsets by a non-zero initialValue', () {
      expect(easeInOutQuadJs(0, 10, 100, 400), 10);
      expect(easeInOutQuadJs(400, 10, 100, 400), 110);
    });

    test('handles a negative amountOfChange (animating backwards)', () {
      expect(easeInOutQuadJs(400, 100, -100, 400), 0);
      expect(easeInOutQuadJs(200, 100, -100, 400), 50);
    });
  });

  group('EaseInOutQuadCurve', () {
    const curve = EaseInOutQuadCurve();

    test('matches easeInOutQuadJs(t, 0, 1, 1) at sampled points', () {
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(curve.transform(t), easeInOutQuadJs(t, 0, 1, 1));
      }
    });

    test('starts at 0 and ends at 1', () {
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
    });

    test('is exactly 0.5 at t=0.5', () {
      expect(curve.transform(0.5), 0.5);
    });
  });
}
