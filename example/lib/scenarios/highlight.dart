/// Single-element `highlight()` scenarios: simple/animated/transition,
/// off-screen scroll-into-view, nested/inner-scroll targets, the
/// element-less centered dummy, dim/backdrop color variants, and
/// `allowClose: false`.
library;

import 'dart:async';
import 'dart:ui' show Color;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

final highlightGroup = ScenarioGroup(
  title: 'Highlight',
  scenarios: [
    Scenario(
      id: 'highlight-simple',
      title: 'Simple highlight',
      description: 'A single highlight() call on Card One, no popover.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(DriveStep(element: ctx.keys.card1));
        ctx.log('highlight-simple: highlight(card1)');
      },
    ),
    Scenario(
      id: 'highlight-animated',
      title: 'Animated highlight',
      description:
          'highlight() with a popover, using the default 400ms '
          'animated stage transition.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context, animate: true));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card2,
            popover: const DriverPopover(
              title: 'Animated highlight',
              description: 'The stage eases into place over 400ms.',
            ),
          ),
        );
        ctx.log('highlight-animated: highlight(card2)');
      },
    ),
    Scenario(
      id: 'highlight-transition',
      title: 'Transition between elements',
      description:
          'Two sequential highlight() calls: card1, then card3 '
          'a second later — watch the stage chase across.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.card1,
            popover: const DriverPopover(
              title: 'Step A',
              description: 'Card one.',
            ),
          ),
        );
        ctx.log('highlight-transition: highlight(card1)');
        Timer(const Duration(seconds: 1), () {
          if (!d.isActive()) return;
          d.highlight(
            DriveStep(
              element: ctx.keys.card3,
              popover: const DriverPopover(
                title: 'Step B',
                description: 'Card three — watch the transition.',
              ),
            ),
          );
          ctx.log('highlight-transition: highlight(card3)');
        });
      },
    ),
    Scenario(
      id: 'highlight-off-screen',
      title: 'Off-screen target',
      description:
          'Highlights an element below the fold — the page '
          'scrolls it into view while the stage chases it.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.belowFold,
            popover: const DriverPopover(
              title: 'Off-screen',
              description: 'Scrolled into view automatically.',
            ),
          ),
        );
        ctx.log('highlight-off-screen: highlight(belowFold)');
      },
    ),
    Scenario(
      id: 'highlight-nested',
      title: 'Nested element',
      description:
          'Highlights a widget nested a few levels deep in the '
          'stage (the feature checklist card).',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.featureList,
            popover: const DriverPopover(
              title: 'Nested',
              description: 'This element is nested inside a Card.',
            ),
          ),
        );
        ctx.log('highlight-nested: highlight(featureList)');
      },
    ),
    Scenario(
      id: 'highlight-inner-scroll',
      title: 'Inner scroll target',
      description:
          'Highlights an item inside the 300px inner ListView, '
          'demonstrating the nested-scroll rect tracking.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.innerScrollItem3,
            popover: const DriverPopover(
              title: 'Inner scroll',
              description:
                  'Lives inside a nested, independently '
                  'scrollable list.',
            ),
          ),
        );
        ctx.log('highlight-inner-scroll: highlight(innerScrollItem3)');
      },
    ),
    Scenario(
      id: 'highlight-no-element',
      title: 'No element (centered)',
      description:
          'An element-less highlight — a zero-size dummy '
          'centered in the viewport with a popover.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          const DriveStep(
            element: null,
            popover: DriverPopover(
              title: 'No element',
              description:
                  'This popover is centered — there is nothing '
                  'to point at.',
            ),
          ),
        );
        ctx.log('highlight-no-element: highlight(element: null)');
      },
    ),
    Scenario(
      id: 'highlight-dark-dim',
      title: 'Dark dim / backdrop color',
      description: 'A heavier, near-opaque black backdrop.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            overlayColor: const Color(0xFF000000),
            overlayOpacity: 0.92,
          ),
        );
        ctx.registerDriver(d);
        d.highlight(DriveStep(element: ctx.keys.card4));
        ctx.log('highlight-dark-dim: overlayOpacity=0.92');
      },
    ),
    Scenario(
      id: 'highlight-colored-backdrop',
      title: 'Colored backdrop',
      description: 'A blue-tinted, lighter backdrop instead of black.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            overlayColor: const Color(0xFF1D4ED8),
            overlayOpacity: 0.55,
          ),
        );
        ctx.registerDriver(d);
        d.highlight(DriveStep(element: ctx.keys.card5));
        ctx.log('highlight-colored-backdrop: overlayColor=blue, opacity=0.55');
      },
    ),
    Scenario(
      id: 'highlight-disallow-close',
      title: 'Disallow close',
      description:
          'allowClose: false — Escape and the overlay-click close '
          'no longer dismiss the highlight; the close button is hidden too.',
      run: (ctx) {
        final d = driver(
          DriverConfig(
            context: ctx.context,
            allowClose: false,
            steps: [
              DriveStep(
                element: ctx.keys.card6,
                popover: const DriverPopover(
                  title: 'Cannot close',
                  description:
                      'allowClose is false: Escape/overlay-click '
                      'do nothing and there is no × button. Only Done '
                      'ends this.',
                ),
              ),
            ],
          ),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('highlight-disallow-close: allowClose=false');
      },
    ),
  ],
);
