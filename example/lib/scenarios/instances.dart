/// Two independent `Driver` instances run sequentially, demonstrating the
/// no-global-state, per-instance design — the second driver only starts
/// once the first one's `onDestroyed` hook fires.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

final instancesGroup = ScenarioGroup(
  title: 'Multiple instances',
  scenarios: [
    Scenario(
      id: 'instances-sequential',
      title: 'Two sequential driver instances',
      description:
          'Driver A tours cards 1-2, then Driver B (a completely '
          'separate instance) tours cards 4-5.',
      run: (ctx) {
        final driverB = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card4,
                popover: const DriverPopover(
                  title: 'Driver B — step 1',
                  description:
                      'A brand new Driver instance, unrelated to '
                      'the first one.',
                ),
              ),
              DriveStep(
                element: ctx.keys.card5,
                popover: const DriverPopover(title: 'Driver B — step 2'),
              ),
            ],
          ),
        );

        final driverA = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Driver A — step 1',
                  description: 'The first, independent Driver instance.',
                ),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(title: 'Driver A — step 2'),
              ),
            ],
            onDestroyed: (element, step, opts) {
              ctx.log('instances-sequential: driver A destroyed, starting B');
              ctx.registerDriver(driverB);
              driverB.drive();
            },
          ),
        );

        ctx.registerDriver(driverA);
        driverA.drive();
        ctx.log('instances-sequential: driver A started');
      },
    ),
  ],
);
