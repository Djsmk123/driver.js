// Widget-level coverage for M4's `shouldSkipStep`-driven skip walk in
// `driver.dart`'s `_drive` (design decision #9): config-level
// `skipMissingElement` vs. a step-level override, and the walk's
// deliberate asymmetry — forward-exhausted destroys, backward-exhausted
// stays put.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a `MaterialApp` with two present, keyed targets and returns the
/// app's `BuildContext`. A third ("missing") `GlobalKey` used by callers is
/// deliberately never attached to anything in this tree, so it never
/// resolves.
Future<BuildContext> _pumpApp(
  WidgetTester tester,
  GlobalKey key0,
  GlobalKey key2,
) async {
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return Stack(
              children: [
                SizedBox(key: key0, width: 40, height: 20),
                SizedBox(key: key2, width: 40, height: 20),
              ],
            );
          },
        ),
      ),
    ),
  );

  return appContext;
}

void main() {
  testWidgets(
    'config-level skipMissingElement skips a step whose element never '
    'resolves',
    (tester) async {
      final key0 = GlobalKey();
      final missingKey = GlobalKey();
      final key2 = GlobalKey();
      final appContext = await _pumpApp(tester, key0, key2);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          skipMissingElement: true,
          steps: [
            DriveStep(element: key0),
            DriveStep(element: missingKey),
            DriveStep(element: key2),
          ],
        ),
      );

      // Cold start directly on the skippable middle step: no prior
      // `activeIndex` to compare against, so the walk defaults forward
      // (`direction = 1`) and lands on step 2.
      d.moveTo(1);
      await tester.pumpAndSettle();

      expect(d.getActiveIndex(), 2);
      expect(d.getActiveElement(), key2.currentContext);
    },
  );

  testWidgets(
    'a step-level skipMissingElement:true override skips even when the '
    'config default is false',
    (tester) async {
      final key0 = GlobalKey();
      final missingKey = GlobalKey();
      final key2 = GlobalKey();
      final appContext = await _pumpApp(tester, key0, key2);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(element: key0),
            DriveStep(element: missingKey, skipMissingElement: true),
            DriveStep(element: key2),
          ],
        ),
      );

      d.moveTo(1);
      await tester.pumpAndSettle();

      expect(d.getActiveIndex(), 2);
    },
  );

  testWidgets('a step-level skipMissingElement:false override keeps a missing '
      'element from being skipped even when the config default is true', (
    tester,
  ) async {
    final key0 = GlobalKey();
    final missingKey = GlobalKey();
    final key2 = GlobalKey();
    final appContext = await _pumpApp(tester, key0, key2);

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        skipMissingElement: true,
        steps: [
          DriveStep(element: key0),
          DriveStep(element: missingKey, skipMissingElement: false),
          DriveStep(element: key2),
        ],
      ),
    );

    d.moveTo(1);
    await tester.pumpAndSettle();

    // Falls back to a centered dummy highlight instead of being skipped.
    expect(d.getActiveIndex(), 1);
    expect(d.getActiveElement(), isNull);
  });

  testWidgets('a forward skip walk that runs off the end destroys the driver', (
    tester,
  ) async {
    final key0 = GlobalKey();
    final missingKey = GlobalKey();
    final appContext = await _pumpApp(tester, key0, GlobalKey());

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        skipMissingElement: true,
        steps: [
          DriveStep(element: key0),
          DriveStep(element: missingKey),
        ],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 0);

    // Step 1 is skippable and it's the last step — the walk runs off the
    // end going forward, which destroys the driver (unlike the backward
    // case below).
    d.moveTo(1);
    await tester.pumpAndSettle();

    expect(d.isActive(), isFalse);
  });

  testWidgets(
    'a backward skip walk that runs off the start stays put instead of '
    'destroying',
    (tester) async {
      final missingKey = GlobalKey();
      final key1 = GlobalKey();
      final appContext = await _pumpApp(tester, GlobalKey(), key1);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          skipMissingElement: true,
          steps: [
            DriveStep(element: missingKey),
            DriveStep(element: key1),
          ],
        ),
      );

      d.drive(1);
      await tester.pumpAndSettle();
      expect(d.getActiveIndex(), 1);

      // Step 0 is skippable and it's the first step — the walk runs off
      // the start going backward, which (per design decision #9) leaves
      // the driver exactly where it was: still active, index unchanged.
      d.moveTo(0);
      await tester.pumpAndSettle();

      expect(d.isActive(), isTrue);
      expect(d.getActiveIndex(), 1);
    },
  );
}
