// Widget-level coverage for M4's `disableActiveInteraction` (design
// decision #4): with it on, a hole tap is swallowed entirely — it doesn't
// reach the target's own gesture handler and doesn't advance even if
// `advanceOnClick` is also on; with it off (default), hole taps reach the
// target normally.

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(BuildContext, GlobalKey, List<bool>)> _pumpApp(
  WidgetTester tester,
) async {
  final targetKey = GlobalKey();
  final tapped = [false];
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
                  left: 20,
                  top: 20,
                  child: GestureDetector(
                    onTap: () => tapped[0] = true,
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

  return (appContext, targetKey, tapped);
}

void main() {
  testWidgets(
    "disableActiveInteraction:true swallows hole taps — the target's own "
    'handler never fires, and advanceOnClick never fires either',
    (tester) async {
      final (appContext, targetKey, tapped) = await _pumpApp(tester);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          steps: [
            DriveStep(
              element: targetKey,
              disableActiveInteraction: true,
              advanceOnClick: true,
            ),
            const DriveStep(),
          ],
        ),
      );

      d.drive(0);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(70, 40));
      await tester.pumpAndSettle();

      expect(tapped[0], isFalse);
      expect(d.getActiveIndex(), 0);
    },
  );

  testWidgets(
    'disableActiveInteraction:false (default) lets hole taps reach the '
    "target's own handler normally",
    (tester) async {
      final (appContext, targetKey, tapped) = await _pumpApp(tester);

      final d = driver(DriverConfig(animate: false, context: appContext));

      d.highlight(DriveStep(element: targetKey));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(70, 40));
      await tester.pumpAndSettle();

      expect(tapped[0], isTrue);
      expect(d.isActive(), isTrue);
    },
  );

  testWidgets(
    'a step-level disableActiveInteraction:true override applies even when '
    'the config default is false',
    (tester) async {
      final (appContext, targetKey, tapped) = await _pumpApp(tester);

      final d = driver(
        DriverConfig(
          animate: false,
          context: appContext,
          disableActiveInteraction: false,
        ),
      );

      d.highlight(
        DriveStep(element: targetKey, disableActiveInteraction: true),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(70, 40));
      await tester.pumpAndSettle();

      expect(tapped[0], isFalse);
    },
  );
}
