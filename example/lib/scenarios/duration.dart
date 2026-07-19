/// The same two-step transition run at several `duration`s, to feel the
/// animation speed range.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

Scenario _durationScenario(int ms) {
  return Scenario(
    id: 'duration-${ms}ms',
    title: '${ms}ms',
    description: 'A card1 → card3 transition with duration: ${ms}ms.',
    run: (ctx) {
      final d = driver(
        DriverConfig(
          context: ctx.context,
          duration: Duration(milliseconds: ms),
          steps: [
            DriveStep(
              element: ctx.keys.card1,
              popover: DriverPopover(
                title:
                    '$ms'
                    'ms transition — step 1',
              ),
            ),
            DriveStep(
              element: ctx.keys.card3,
              popover: const DriverPopover(title: 'Step 2'),
            ),
          ],
        ),
      );
      ctx.registerDriver(d);
      d.drive();
      ctx.log('duration-${ms}ms: started');
    },
  );
}

final durationGroup = ScenarioGroup(
  title: 'Duration',
  scenarios: [
    _durationScenario(100),
    _durationScenario(400),
    _durationScenario(1000),
    _durationScenario(2000),
  ],
);
