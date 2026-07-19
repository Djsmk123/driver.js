/// `skipMissingElement` scenarios at both the config and step level,
/// against an element that is never mounted during the scenario.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

final skipMissingGroup = ScenarioGroup(
  title: 'Skip missing element',
  scenarios: [
    Scenario(
      id: 'skip-missing-config-level',
      title: 'Config-level skipMissingElement',
      description:
          'DriverConfig.skipMissingElement: true — step 2\'s '
          'element never mounts, so it is skipped for every step.',
      run: (ctx) {
        ctx.unmountLateElement();
        final d = driver(
          DriverConfig(
            context: ctx.context,
            skipMissingElement: true,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Step 1',
                  description:
                      'skipMissingElement is true at the config '
                      'level.',
                ),
              ),
              DriveStep(
                element: ctx.keys.lateElement,
                popover: const DriverPopover(
                  title: 'You should never see this',
                ),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(
                  title: 'Step 3',
                  description: 'Reached directly — step 2 was skipped.',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('skip-missing-config-level: started');
      },
    ),
    Scenario(
      id: 'skip-missing-step-level',
      title: 'Step-level skipMissingElement',
      description:
          'Only step 2 sets skipMissingElement: true; config '
          'default stays false.',
      run: (ctx) {
        ctx.unmountLateElement();
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Step 1',
                  description:
                      'Only the next step sets '
                      'skipMissingElement itself.',
                ),
              ),
              DriveStep(
                element: ctx.keys.lateElement,
                skipMissingElement: true,
                popover: const DriverPopover(
                  title: 'You should never see this',
                ),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(
                  title: 'Step 3',
                  description:
                      'Reached directly — step 2 was skipped by '
                      'its own override.',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('skip-missing-step-level: started');
      },
    ),
  ],
);
