// End-to-end (widget-level) coverage for M1's highlight-only `Driver`:
// mounting the overlay, dimming the screen with a hole roughly matching the
// target rect (verified behaviorally — dim taps close, hole taps pass
// through to the highlighted widget), and tearing the overlay down again
// on `destroy()`.

import 'package:driverjs/driverjs.dart';
import 'package:driverjs/src/overlay_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'highlight dims the screen with a translucent hole over the target',
    (tester) async {
      final targetKey = GlobalKey();
      var targetTapped = false;
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
                      child: GestureDetector(
                        onTap: () => targetTapped = true,
                        child: SizedBox(
                          key: targetKey,
                          width: 100,
                          height: 40,
                          child: const ColoredBox(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // animate: false so the stage snaps to its final rect synchronously
      // (no ticker to pump through), keeping the test focused on mounting +
      // hit-testing rather than the animation itself (covered by utils_test).
      final d = driver(DriverConfig(animate: false, context: appContext));

      expect(d.isActive(), isFalse);

      d.highlight(DriveStep(element: targetKey));
      await tester.pumpAndSettle();

      expect(d.isActive(), isTrue);
      expect(find.byType(DriverOverlay), findsOneWidget);

      // A tap inside the hole (on the target) must reach the target's own
      // gesture handler underneath — the hole is translucent — and must NOT
      // close the overlay.
      await tester.tapAt(const Offset(100, 70));
      await tester.pumpAndSettle();
      expect(targetTapped, isTrue);
      expect(d.isActive(), isTrue);

      // A tap in the dim region (far from the target) hits the cutout's
      // opaque dim paint and triggers the default overlayClickBehavior
      // (`.close()`, with `allowClose: true` by default), destroying the
      // driver.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(d.isActive(), isFalse);
      expect(find.byType(DriverOverlay), findsNothing);
    },
  );

  testWidgets('destroy() removes the overlay entry', (tester) async {
    final targetKey = GlobalKey();
    late BuildContext appContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appContext = context;
              return Center(
                child: SizedBox(key: targetKey, width: 80, height: 30),
              );
            },
          ),
        ),
      ),
    );

    final d = driver(DriverConfig(animate: false, context: appContext));
    d.highlight(DriveStep(element: targetKey));
    await tester.pumpAndSettle();

    expect(d.isActive(), isTrue);
    expect(find.byType(DriverOverlay), findsOneWidget);

    d.destroy();
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
    expect(find.byType(DriverOverlay), findsNothing);

    // destroy() is idempotent.
    expect(() => d.destroy(), returnsNormally);
  });

  testWidgets(
    'an element-less step highlights a zero-size dummy at the overlay center',
    (tester) async {
      late BuildContext appContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      final d = driver(DriverConfig(animate: false, context: appContext));
      d.highlight(const DriveStep(element: null));
      await tester.pumpAndSettle();

      expect(d.isActive(), isTrue);
      expect(d.getActiveElement(), isNull);
    },
  );
}
