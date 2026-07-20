/// `advanceOnClick` and `waitForElement` scenarios.
library;

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';

import '../scenario.dart';

/// A small spinner + caption used on steps whose popover is on screen for
/// the entire `waitForElement` hold — without this the tour just looks
/// stalled for the timeout duration rather than visibly waiting.
Widget _waitingIndicator(String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

final advanceWaitGroup = ScenarioGroup(
  title: 'Advance & wait',
  scenarios: [
    Scenario(
      id: 'advance-on-click-two-steps',
      title: 'advanceOnClick on two steps',
      description:
          'Tapping the highlighted card itself advances the '
          'tour, on both step 1 and step 2.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card4,
                advanceOnClick: true,
                popover: const DriverPopover(
                  title: 'Tap the card',
                  description:
                      'advanceOnClick is on for this step — tap '
                      'Card Four itself to move on.',
                ),
              ),
              DriveStep(
                element: ctx.keys.card2,
                advanceOnClick: true,
                popover: const DriverPopover(
                  title: 'Tap again',
                  description: 'advanceOnClick is also on here.',
                ),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(title: 'Done'),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('advance-on-click-two-steps: started');
      },
    ),
    Scenario(
      id: 'wait-for-element',
      title: 'waitForElement',
      description:
          'Step 2 targets an element that is not mounted yet — '
          'the tour waits, then jumps to it once mountLateElement() runs '
          '(triggered here after 1.5s).',
      run: (ctx) {
        ctx.unmountLateElement();
        final d = driver(
          DriverConfig(
            context: ctx.context,
            waitForElement: const Duration(seconds: 5),
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: DriverPopover(
                  title: 'Waiting for a late element',
                  descriptionWidget: _waitingIndicator(
                    'Step 2 targets an element that mounts in ~1.5s. '
                    'Press Next to see the tour wait for it.',
                  ),
                ),
              ),
              DriveStep(
                element: ctx.keys.lateElement,
                popover: const DriverPopover(
                  title: 'It appeared!',
                  description:
                      'waitForElement held the tour here until '
                      'the element mounted.',
                ),
                onHighlightStarted: (element, step, opts) {
                  ctx.log('wait-for-element: element resolved, highlighting');
                },
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('wait-for-element: started, waitForElement=5s');
        Future.delayed(const Duration(milliseconds: 1500), () {
          ctx.mountLateElement();
          ctx.log('wait-for-element: mountLateElement() called');
        });
      },
    ),
    Scenario(
      id: 'wait-timeout-then-skip',
      title: 'Wait timeout then skip',
      description:
          'The waited-for element never mounts; after the '
          'timeout, skipMissingElement: true skips straight past it.',
      run: (ctx) {
        ctx.unmountLateElement();
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: DriverPopover(
                  title: 'About to skip a step',
                  descriptionWidget: _waitingIndicator(
                    'Step 2 will never mount and times out after 1s, '
                    'then gets skipped.',
                  ),
                ),
              ),
              DriveStep(
                element: ctx.keys.lateElement,
                waitForElement: const Duration(seconds: 1),
                skipMissingElement: true,
                popover: const DriverPopover(
                  title: 'You should never see this',
                ),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(
                  title: 'Skipped straight here',
                  description:
                      'Step 2 timed out and was skipped because '
                      'skipMissingElement was true.',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('wait-timeout-then-skip: started');
      },
    ),
  ],
);
