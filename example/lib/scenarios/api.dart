/// Imperative API scenarios: every `DriverConfig` hook wired to the log
/// panel, an `isActive()`/`moveTo()`/`getState()` inspector, and a
/// `destroy()` button.
library;

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';

import '../scenario.dart';

final apiGroup = ScenarioGroup(
  title: 'API',
  scenarios: [
    Scenario(
      id: 'api-hooks-logger',
      title: 'Every hook, logged',
      description:
          'Every DriverConfig lifecycle/click hook wired to the '
          'event log — watch it fire as you navigate a 2-step tour.',
      run: (ctx) {
        late final Driver d;
        d = driver(
          DriverConfig(
            context: ctx.context,
            onHighlightStarted: (e, s, o) =>
                ctx.log('onHighlightStarted: index=${o.index}'),
            onHighlighted: (e, s, o) =>
                ctx.log('onHighlighted: index=${o.index}'),
            onDeselected: (e, s, o) =>
                ctx.log('onDeselected: index=${o.index}'),
            onDestroyStarted: (e, s, o) {
              ctx.log('onDestroyStarted: index=${o.index}');
              o.driver.destroy();
            },
            onDestroyed: (e, s, o) => ctx.log('onDestroyed'),
            onNextClick: (e, s, o) {
              ctx.log('onNextClick');
              o.driver.moveNext();
            },
            onPrevClick: (e, s, o) {
              ctx.log('onPrevClick');
              o.driver.movePrevious();
            },
            onCloseClick: (e, s, o) {
              ctx.log('onCloseClick');
              o.driver.destroy();
            },
            onDoneClick: (e, s, o) {
              ctx.log('onDoneClick');
              o.driver.destroy();
            },
            onPopoverRender: (data, o) =>
                ctx.log('onPopoverRender: "${data.title}"'),
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(title: 'Hooked step 1'),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(title: 'Hooked step 2'),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('api-hooks-logger: started');
      },
    ),
    Scenario(
      id: 'api-state-inspector',
      title: 'State inspector',
      description:
          'Logs isActive()/getActiveIndex()/getState() after '
          'every step, so you can watch the driver\'s introspection API.',
      run: (ctx) {
        late final Driver d;
        void report(String when) {
          final state = d.getState();
          ctx.log(
            '[$when] isActive=${d.isActive()} activeIndex=${d.getActiveIndex()} '
            'isFirstStep=${d.isFirstStep()} isLastStep=${d.isLastStep()} '
            'state.activeIndex=${state.activeIndex}',
          );
        }

        d = driver(
          DriverConfig(
            context: ctx.context,
            onHighlighted: (e, s, o) => report('onHighlighted'),
            onDestroyed: (e, s, o) => report('onDestroyed'),
            steps: [
              DriveStep(element: ctx.keys.card1),
              DriveStep(element: ctx.keys.card2),
              DriveStep(element: ctx.keys.card3),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        report('drive() call');
      },
    ),
    Scenario(
      id: 'api-move-to',
      title: 'moveTo() jump',
      description:
          'Starts on step 1, then jumps straight to step 3 via '
          'moveTo(2) after a short delay, skipping steps 2\'s transition.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(title: 'Step 1'),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(title: 'Step 2 (skipped over)'),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(title: 'Step 3 — jumped here'),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('api-move-to: started on step 1');
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!d.isActive()) return;
          d.moveTo(2);
          ctx.log('api-move-to: moveTo(2) called');
        });
      },
    ),
    Scenario(
      id: 'api-destroy-button',
      title: 'destroy() button',
      description:
          'Starts a highlight, then shows a snackbar with a '
          'button that calls driver.destroy() directly.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card1,
            popover: const DriverPopover(
              title: 'Destroy me externally',
              description:
                  'Use the snackbar button below, not the × on '
                  'this popover.',
            ),
          ),
        );
        ctx.log('api-destroy-button: highlight started');

        ScaffoldMessenger.of(ctx.context).showSnackBar(
          SnackBar(
            content: const Text('Highlight active.'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'destroy()',
              onPressed: () {
                d.destroy();
                ctx.log('api-destroy-button: destroy() called');
              },
            ),
          ),
        );
      },
    ),
  ],
);
