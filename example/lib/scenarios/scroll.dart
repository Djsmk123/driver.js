/// `allowScroll`/`smoothScroll` scenarios, all targeting a below-the-fold
/// element so the scroll-into-view behavior is visible.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

final scrollGroup = ScenarioGroup(
  title: 'Scroll behavior',
  scenarios: [
    Scenario(
      id: 'scroll-allowed-default',
      title: 'allowScroll: true (default)',
      description: 'The page scrolls freely while highlighted.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.belowFold,
            popover: const DriverPopover(
              title: 'Scroll allowed',
              description:
                  'allowScroll defaults to true — try scrolling '
                  'the page while this is highlighted.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('scroll-allowed-default: allowScroll=true (default)');
      },
    ),
    Scenario(
      id: 'scroll-locked',
      title: 'allowScroll: false',
      description: 'The dim region blocks page scrolling while active.',
      run: (ctx) {
        final d = driver(
          DriverConfig(context: ctx.context, allowScroll: false),
        );
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.belowFold,
            popover: const DriverPopover(
              title: 'Scroll locked',
              description:
                  'allowScroll is false — the dim region blocks '
                  'scroll gestures outside the cutout.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('scroll-locked: allowScroll=false');
      },
    ),
    Scenario(
      id: 'scroll-smooth',
      title: 'smoothScroll: true',
      description:
          'The scroll-into-view itself animates instead of '
          'jumping.',
      run: (ctx) {
        final d = driver(
          DriverConfig(context: ctx.context, smoothScroll: true),
        );
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.belowFold,
            popover: const DriverPopover(
              title: 'Smooth scroll',
              description:
                  'smoothScroll is true — the page eases into '
                  'view instead of jumping.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('scroll-smooth: smoothScroll=true');
      },
    ),
  ],
);
