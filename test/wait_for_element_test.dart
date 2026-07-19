// Widget-level coverage for M4's `waitForElement` polling in
// `driver.dart`'s `_drive`/`_waitForStepElement`: staying on the current
// step while waiting, resolving mid-wait once the element mounts,
// timing out into either a skip walk or a centered dummy highlight
// depending on `skipMissingElement`, and cancellation (`drive()` again or
// `destroy()` mid-wait must not let the stale wait resolve later).

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a `MaterialApp` with an always-present target ([key0]) and a
/// second target ([lateKey]) that only mounts once [showLate] flips to
/// `true`, returning the app's `BuildContext` for `DriverConfig.context`.
Future<BuildContext> _pumpApp(
  WidgetTester tester, {
  required GlobalKey key0,
  required GlobalKey lateKey,
  required ValueNotifier<bool> showLate,
}) async {
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return ValueListenableBuilder<bool>(
              valueListenable: showLate,
              builder: (context, showLateValue, _) => Stack(
                children: [
                  SizedBox(key: key0, width: 40, height: 20),
                  if (showLateValue)
                    SizedBox(key: lateKey, width: 40, height: 20),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  return appContext;
}

void main() {
  testWidgets('a step whose element is not yet mounted stays waiting, then '
      'highlights once it mounts mid-wait', (tester) async {
    final key0 = GlobalKey();
    final lateKey = GlobalKey();
    final showLate = ValueNotifier<bool>(false);
    addTearDown(showLate.dispose);

    final appContext = await _pumpApp(
      tester,
      key0: key0,
      lateKey: lateKey,
      showLate: showLate,
    );

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        waitForElement: const Duration(seconds: 2),
        steps: [
          DriveStep(element: key0),
          DriveStep(element: lateKey),
        ],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();
    expect(d.getActiveIndex(), 0);

    d.drive(1);
    await tester.pump();

    // Still waiting: the previous step's index is untouched, and no
    // FlutterError was thrown despite the target not existing yet.
    expect(d.getActiveIndex(), 0);
    expect(d.isActive(), isTrue);

    // Mount the late element mid-wait and let the post-frame poll notice.
    showLate.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 1);
    expect(d.getActiveElement(), lateKey.currentContext);
  });

  testWidgets('timeout with skipMissingElement:true skips forward to the next '
      'resolvable step', (tester) async {
    final key0 = GlobalKey();
    final missingKey = GlobalKey();
    final key2 = GlobalKey();
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

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        skipMissingElement: true,
        steps: [
          DriveStep(element: key0),
          DriveStep(
            element: missingKey,
            waitForElement: const Duration(milliseconds: 100),
          ),
          DriveStep(element: key2),
        ],
      ),
    );

    d.drive(1);
    // Waiting: index not yet set.
    await tester.pump();
    expect(d.getActiveIndex(), isNull);

    // Fire the timeout, then let the skip walk + highlight settle.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(d.getActiveIndex(), 2);
    expect(d.getActiveElement(), key2.currentContext);
  });

  testWidgets(
    'timeout with skipMissingElement:false falls back to a centered dummy '
    'highlight',
    (tester) async {
      final key0 = GlobalKey();
      final missingKey = GlobalKey();
      late BuildContext appContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return SizedBox(key: key0, width: 40, height: 20);
              },
            ),
          ),
        ),
      );

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(element: key0),
            DriveStep(
              element: missingKey,
              waitForElement: const Duration(milliseconds: 100),
            ),
          ],
        ),
      );

      d.drive(1);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(d.getActiveIndex(), 1);
      expect(d.getActiveElement(), isNull);
      expect(d.isActive(), isTrue);
    },
  );

  testWidgets(
    'calling drive() again mid-wait cancels the pending wait so it never '
    'resolves stale',
    (tester) async {
      final key0 = GlobalKey();
      final missingKey = GlobalKey();
      final key2 = GlobalKey();
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

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(element: key0),
            DriveStep(
              element: missingKey,
              waitForElement: const Duration(seconds: 5),
            ),
            DriveStep(element: key2),
          ],
        ),
      );

      // Start waiting on step 1 (never mounts).
      d.drive(1);
      await tester.pump();
      expect(d.getActiveIndex(), isNull);

      // Navigate away before the wait resolves.
      d.drive(0);
      await tester.pumpAndSettle();
      expect(d.getActiveIndex(), 0);

      // Advance well past the original wait's timeout. If it weren't
      // cancelled, its `Timer` would fire here and re-enter `_drive(1, ...)`,
      // clobbering the index this test just settled on. Also asserts no
      // pending-`Timer` failure from flutter_test's fake-async teardown.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(d.getActiveIndex(), 0);
    },
  );

  testWidgets('calling destroy() mid-wait cancels the pending wait cleanly', (
    tester,
  ) async {
    final key0 = GlobalKey();
    final missingKey = GlobalKey();
    late BuildContext appContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appContext = context;
              return SizedBox(key: key0, width: 40, height: 20);
            },
          ),
        ),
      ),
    );

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [
          DriveStep(element: key0),
          DriveStep(
            element: missingKey,
            waitForElement: const Duration(seconds: 5),
          ),
        ],
      ),
    );

    // Mount first (on a resolvable step) so `isActive()` reflects the
    // overlay's mounted-ness rather than the wait's own deferred mount.
    d.drive(0);
    await tester.pumpAndSettle();
    expect(d.isActive(), isTrue);

    d.drive(1);
    await tester.pump();
    expect(d.isActive(), isTrue);

    d.destroy();
    await tester.pumpAndSettle();
    expect(d.isActive(), isFalse);

    // No pending Timer left to fire (and no stale re-entry into a
    // destroyed driver's `_drive`).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(d.isActive(), isFalse);
  });
}
