/// Multi-step tour scenarios: animated/static, progress templating, an
/// async hook-driven step, confirm-on-exit, prevent-close,
/// keyboard-disabled, and both overlay-click-next modes.
library;

import 'dart:async';

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';

import '../scenario.dart';

final tourGroup = ScenarioGroup(
  title: 'Tour',
  scenarios: [
    Scenario(
      id: 'tour-animated',
      title: 'Animated multi-step tour',
      description:
          'A 4-step tour with the default 400ms animated '
          'transitions between cards.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Step 1',
                  description: 'The tour starts here.',
                ),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(title: 'Step 2'),
              ),
              DriveStep(
                element: ctx.keys.card3,
                popover: const DriverPopover(title: 'Step 3'),
              ),
              DriveStep(
                element: ctx.keys.card4,
                popover: const DriverPopover(
                  title: 'Step 4',
                  description: 'Last step — Next now reads Done.',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-animated: started 4-step tour');
      },
    ),
    Scenario(
      id: 'tour-static',
      title: 'Static (no animation)',
      description:
          'animate: false — the stage snaps instantly between '
          'steps.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            animate: false,
            steps: [
              DriveStep(element: ctx.keys.card1),
              DriveStep(element: ctx.keys.card2),
              DriveStep(element: ctx.keys.card3),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-static: animate=false');
      },
    ),
    Scenario(
      id: 'tour-progress-template',
      title: 'Progress with template',
      description:
          'showProgress: true, progressText using the '
          '{{current}}/{{total}} template.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            showProgress: true,
            progressText: 'Step {{current}} of {{total}}',
            steps: [
              DriveStep(element: ctx.keys.card1),
              DriveStep(element: ctx.keys.card2),
              DriveStep(element: ctx.keys.card3),
              DriveStep(element: ctx.keys.card4),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-progress-template: started');
      },
    ),
    Scenario(
      id: 'tour-async-step',
      title: 'Async auto-advance step',
      description:
          'onHighlighted starts a 1.5s timer that calls '
          'driver.moveNext() automatically.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Loading…',
                  description: 'This step auto-advances in 1.5 seconds.',
                  showButtons: [DriverButton.close],
                ),
                onHighlighted: (element, step, opts) {
                  ctx.log('tour-async-step: waiting 1.5s to auto-advance');
                  Timer(const Duration(milliseconds: 1500), () {
                    if (opts.driver.isActive()) opts.driver.moveNext();
                  });
                },
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(
                  title: 'Arrived automatically',
                  description: 'onHighlighted\'s timer called moveNext().',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
      },
    ),
    Scenario(
      id: 'tour-confirm-exit',
      title: 'Confirm on exit',
      description:
          'onDestroyStarted shows a confirmation dialog before '
          'the tour is allowed to close.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Try closing me',
                  description:
                      'Press Escape or the × — you\'ll be asked '
                      'to confirm.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
            ],
            onDestroyStarted: (element, step, opts) async {
              ctx.log('onDestroyStarted: asking for confirmation');
              final confirmed = await showDialog<bool>(
                context: ctx.context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('End tour?'),
                  content: const Text('Are you sure you want to exit?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) {
                ctx.log('onDestroyStarted: confirmed, destroying');
                opts.driver.destroy();
              } else {
                ctx.log('onDestroyStarted: cancelled, staying open');
              }
            },
          ),
        );
        ctx.registerDriver(d);
        d.drive();
      },
    ),
    Scenario(
      id: 'tour-prevent-close',
      title: 'Prevent close',
      description:
          'allowClose: false on a tour — only Next/Done can end '
          'it.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            allowClose: false,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'No escape',
                  description:
                      'Escape/overlay-click do nothing; there is '
                      'no × button.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-prevent-close: allowClose=false');
      },
    ),
    Scenario(
      id: 'tour-keyboard-disabled',
      title: 'Keyboard disabled',
      description:
          'allowKeyboardControl: false — arrow keys/Escape do '
          'nothing; only the buttons navigate.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            allowKeyboardControl: false,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'No keyboard',
                  description: 'Arrow keys and Escape are ignored here.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-keyboard-disabled: allowKeyboardControl=false');
      },
    ),
    Scenario(
      id: 'tour-overlay-click-next',
      title: 'Overlay click → next step',
      description:
          'overlayClickBehavior: nextStep — tapping the dimmed '
          'backdrop advances the tour instead of closing it.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            overlayClickBehavior: const OverlayClickBehavior.nextStep(),
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Tap the backdrop',
                  description:
                      'Clicking anywhere outside the cutout '
                      'advances to the next step.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
              DriveStep(element: ctx.keys.card3),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-overlay-click-next: overlayClickBehavior=nextStep');
      },
    ),
    Scenario(
      id: 'tour-overlay-click-custom',
      title: 'Custom overlay click handler',
      description:
          'overlayClickBehavior.custom logs the click instead of '
          'closing or advancing.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            overlayClickBehavior: OverlayClickBehavior.custom((
              element,
              step,
              opts,
            ) {
              ctx.log(
                'overlayClickBehavior.custom: backdrop tapped on '
                '"${step.popover?.title}"',
              );
            }),
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Custom backdrop handler',
                  description:
                      'Tapping outside the cutout just logs an '
                      'event below — it does nothing else.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('tour-overlay-click-custom: overlayClickBehavior=custom');
      },
    ),
  ],
);
