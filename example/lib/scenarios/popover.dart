/// Popover-focused scenarios: button show/disable combos, custom texts,
/// progress, click listeners, theming, `onPopoverRender`, and a custom
/// footer button appended via `extraFooterChildren`.
library;

import 'dart:ui' show Color;

import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart' show EdgeInsets, TextButton, Text;

import '../scenario.dart';

final popoverGroup = ScenarioGroup(
  title: 'Popover',
  scenarios: [
    Scenario(
      id: 'popover-all-buttons',
      title: 'All buttons shown',
      description: 'showButtons: [previous, next, close] on a 2-step tour.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'All buttons',
                  description: 'Previous, next, and close are all shown.',
                  showButtons: [
                    DriverButton.previous,
                    DriverButton.next,
                    DriverButton.close,
                  ],
                ),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(title: 'Step two'),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('popover-all-buttons: showButtons=[previous,next,close]');
      },
    ),
    Scenario(
      id: 'popover-next-only',
      title: 'Next-only footer',
      description: 'showButtons: [next] — no previous or close button.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card1,
            popover: const DriverPopover(
              title: 'Next only',
              description: 'showButtons: [DriverButton.next]',
              showButtons: [DriverButton.next],
            ),
          ),
        );
        ctx.log('popover-next-only: showButtons=[next]');
      },
    ),
    Scenario(
      id: 'popover-custom-texts',
      title: 'Custom button texts',
      description: 'nextBtnText/prevBtnText/doneBtnText overridden.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'Custom text',
                  description: 'The footer buttons use custom labels.',
                  nextBtnText: 'Continue →',
                  prevBtnText: '← Back',
                ),
              ),
              DriveStep(
                element: ctx.keys.card2,
                popover: const DriverPopover(
                  title: 'Last step',
                  doneBtnText: 'Finish up!',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('popover-custom-texts: nextBtnText/prevBtnText/doneBtnText');
      },
    ),
    Scenario(
      id: 'popover-show-progress',
      title: 'Progress indicator',
      description:
          'showProgress: true with the {{current}}/{{total}} '
          'template.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            showProgress: true,
            progressText: '{{current}} / {{total}}',
            steps: [
              DriveStep(element: ctx.keys.card1),
              DriveStep(element: ctx.keys.card2),
              DriveStep(element: ctx.keys.card3),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('popover-show-progress: showProgress=true');
      },
    ),
    Scenario(
      id: 'popover-disabled-buttons',
      title: 'Disabled buttons',
      description: 'disableButtons: [previous] — rendered but unusable.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card1,
            popover: const DriverPopover(
              title: 'Disabled previous',
              showButtons: [DriverButton.previous, DriverButton.next],
              disableButtons: [DriverButton.previous],
            ),
          ),
        );
        ctx.log('popover-disabled-buttons: disableButtons=[previous]');
      },
    ),
    Scenario(
      id: 'popover-button-listeners',
      title: 'Button click listeners',
      description:
          'onNextClick/onPrevClick/onCloseClick all log, then '
          'still navigate.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            onNextClick: (element, step, opts) {
              ctx.log('onNextClick fired');
              opts.driver.moveNext();
            },
            onPrevClick: (element, step, opts) {
              ctx.log('onPrevClick fired');
              opts.driver.movePrevious();
            },
            onCloseClick: (element, step, opts) {
              ctx.log('onCloseClick fired');
              opts.driver.destroy();
            },
            steps: [
              DriveStep(element: ctx.keys.card1),
              DriveStep(element: ctx.keys.card2),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('popover-button-listeners: started');
      },
    ),
    Scenario(
      id: 'popover-themed',
      title: 'Themed popover',
      description:
          'A custom DriverTheme: dark background, rounder '
          'corners, accent-colored buttons.',
      run: (ctx) {
        final theme = const DriverTheme().copyWith(
          popoverBackgroundColor: const Color(0xFF1E293B),
          popoverTextColor: const Color(0xFFF1F5F9),
          popoverBorderRadius: 16,
          popoverButtonBackgroundColor: const Color(0xFF334155),
          popoverButtonTextColor: const Color(0xFFF1F5F9),
          popoverButtonBorderColor: const Color(0xFF475569),
          popoverProgressTextColor: const Color(0xFF94A3B8),
        );
        final d = driver(DriverConfig(context: ctx.context, theme: theme));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card3,
            popover: const DriverPopover(
              title: 'Dark theme',
              description: 'Styled entirely through DriverTheme.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('popover-themed: custom DriverTheme applied');
      },
    ),
    Scenario(
      id: 'popover-on-render-hook',
      title: 'onPopoverRender hook',
      description:
          'Mutates the resolved DriverPopoverData right before '
          'layout (appends "(edited)" to the title).',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            onPopoverRender: (data, opts) {
              ctx.log('onPopoverRender: title was "${data.title}"');
              data.title = '${data.title ?? ''} (edited)';
            },
          ),
        );
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card4,
            popover: const DriverPopover(
              title: 'Original title',
              description: 'onPopoverRender mutates this before it paints.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
      },
    ),
    Scenario(
      id: 'popover-extra-footer-button',
      title: 'Custom footer button',
      description:
          'onPopoverRender appends an extra widget to the footer '
          'via extraFooterChildren.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            onPopoverRender: (data, opts) {
              data.extraFooterChildren = [
                ...data.extraFooterChildren,
                TextButton(
                  onPressed: () => ctx.log('Custom footer button tapped'),
                  child: const Text('Learn more'),
                ),
              ];
            },
          ),
        );
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card5,
            popover: const DriverPopover(
              title: 'Extra footer button',
              description:
                  'A "Learn more" button was appended by '
                  'onPopoverRender.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
      },
    ),
    Scenario(
      id: 'popover-custom-padding-radius',
      title: 'Custom padding & radius',
      description:
          'DriverTheme.popoverPadding / popoverBorderRadius '
          'overridden for a spacious, sharp-cornered look.',
      run: (ctx) {
        final theme = const DriverTheme().copyWith(
          popoverPadding: const EdgeInsets.all(28),
          popoverBorderRadius: 0,
        );
        final d = driver(DriverConfig(context: ctx.context, theme: theme));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card6,
            popover: const DriverPopover(
              title: 'Spacious & square',
              description: '28px padding, 0 corner radius.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
      },
    ),
  ],
);
