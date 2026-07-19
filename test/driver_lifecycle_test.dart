// Widget-level coverage for `driver.dart`'s lifecycle hooks and destroy
// semantics (design decision #9 in the plan): highlight-hook call order,
// `DriverHookOpts` contents, `onDestroyStarted` intercepting a
// user-initiated close until the hook itself calls `driver.destroy()`, the
// public parameterless `destroy()` always skipping that hook, and focus
// restore after teardown.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, GlobalKey, FocusNode)> _pumpAppWithFocusable(
  WidgetTester tester,
) async {
  final targetKey = GlobalKey();
  final focusNode = FocusNode();
  late BuildContext appContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            appContext = context;
            return Column(
              children: [
                Focus(focusNode: focusNode, child: const SizedBox(width: 10)),
                SizedBox(key: targetKey, width: 40, height: 20),
              ],
            );
          },
        ),
      ),
    ),
  );

  return (appContext, targetKey, focusNode);
}

void main() {
  testWidgets('onHighlightStarted fires before onHighlighted', (tester) async {
    final targetKey = GlobalKey();
    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appContext = context;
              return SizedBox(key: targetKey, width: 40, height: 20);
            },
          ),
        ),
      ),
    );

    final calls = <String>[];
    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [
          DriveStep(
            element: targetKey,
            onHighlightStarted: (_, _, _) => calls.add('onHighlightStarted'),
            onHighlighted: (_, _, _) => calls.add('onHighlighted'),
          ),
        ],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    expect(calls, ['onHighlightStarted', 'onHighlighted']);
  });

  testWidgets('DriverHookOpts carries the live config/state/driver/index', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appContext = context;
              return SizedBox(key: targetKey, width: 40, height: 20);
            },
          ),
        ),
      ),
    );

    DriverHookOpts? captured;
    late Driver d;
    d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [
          DriveStep(
            element: targetKey,
            onHighlighted: (_, _, opts) => captured = opts,
          ),
        ],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.driver, same(d));
    expect(captured!.config, same(d.getConfig()));
    expect(captured!.state, same(d.getState()));
    expect(captured!.index, 0);
  });

  testWidgets(
    'a non-intercepting destroy runs onDeselected then onDestroyed, after '
    'teardown',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext appContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return SizedBox(key: targetKey, width: 40, height: 20);
              },
            ),
          ),
        ),
      );

      final calls = <String>[];
      late Driver d;
      d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(
              element: targetKey,
              onDeselected: (_, _, _) => calls.add('onDeselected'),
            ),
          ],
          onDestroyed: (_, _, _) => calls.add('onDestroyed'),
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      // moveNext() past the only step is a user-initiated close path
      // (`withHook: true`), but there's no `onDestroyStarted` configured
      // here, so it falls straight through to teardown.
      d.moveNext();
      await tester.pumpAndSettle();

      expect(d.isActive(), isFalse);
      expect(calls, ['onDeselected', 'onDestroyed']);
    },
  );

  testWidgets(
    'onDestroyStarted intercepts a user-initiated close; teardown only '
    'happens once the hook calls driver.destroy() itself',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext appContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return SizedBox(key: targetKey, width: 40, height: 20);
              },
            ),
          ),
        ),
      );

      var onDestroyStartedCalls = 0;
      var onDestroyedCalls = 0;
      late Driver d;
      d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [DriveStep(element: targetKey)],
          onDestroyStarted: (_, _, _) => onDestroyStartedCalls++,
          onDestroyed: (_, _, _) => onDestroyedCalls++,
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      // moveNext() past the only step: a user-initiated close.
      d.moveNext();
      await tester.pumpAndSettle();

      // Intercepted: the driver is still active and torn-down hooks never
      // fired, because the confirm-exit hook above never called
      // `driver.destroy()` itself.
      expect(onDestroyStartedCalls, 1);
      expect(onDestroyedCalls, 0);
      expect(d.isActive(), isTrue);
    },
  );

  testWidgets(
    'once onDestroyStarted itself calls driver.destroy(), teardown proceeds',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext appContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return SizedBox(key: targetKey, width: 40, height: 20);
              },
            ),
          ),
        ),
      );

      var onDestroyedCalls = 0;
      late Driver d;
      d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [DriveStep(element: targetKey)],
          onDestroyStarted: (_, _, opts) => opts.driver.destroy(),
          onDestroyed: (_, _, _) => onDestroyedCalls++,
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      d.moveNext();
      await tester.pumpAndSettle();

      expect(d.isActive(), isFalse);
      expect(onDestroyedCalls, 1);
    },
  );

  testWidgets(
    'the public, parameterless destroy() always skips onDestroyStarted',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext appContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                appContext = context;
                return SizedBox(key: targetKey, width: 40, height: 20);
              },
            ),
          ),
        ),
      );

      var onDestroyStartedCalls = 0;
      var onDestroyedCalls = 0;
      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [DriveStep(element: targetKey)],
          onDestroyStarted: (_, _, _) => onDestroyStartedCalls++,
          onDestroyed: (_, _, _) => onDestroyedCalls++,
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      d.destroy();
      await tester.pumpAndSettle();

      expect(onDestroyStartedCalls, 0);
      expect(onDestroyedCalls, 1);
      expect(d.isActive(), isFalse);
    },
  );

  testWidgets('destroy() restores focus to whatever had it before drive()', (
    tester,
  ) async {
    final (appContext, targetKey, focusNode) = await _pumpAppWithFocusable(
      tester,
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final d = driver(
      DriverConfig(
        animate: false,
        context: appContext,
        steps: [DriveStep(element: targetKey)],
      ),
    );

    d.drive(0);
    await tester.pumpAndSettle();

    d.destroy();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
  });
}
