/// Hints scenarios: a basic hint set, a beacon side×align placement
/// matrix, dismiss + restoreAll persistence, hints-hide-during-tour
/// interplay, and overlay-mode hints.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';

final hintsGroup = ScenarioGroup(
  title: 'Hints',
  scenarios: [
    Scenario(
      id: 'hints-basic',
      title: 'Basic hint set',
      description:
          'Three pulsing beacons across cards 1-3, each with its '
          'own popover.',
      run: (ctx) {
        final h = hints(
          HintsConfig(
            context: ctx.context,
            hints: [
              DriverHint(
                element: ctx.keys.card1,
                popover: const HintPopover(
                  title: 'Hint 1',
                  description: 'A basic pulsing beacon on Card One.',
                ),
              ),
              DriverHint(
                element: ctx.keys.card2,
                popover: const HintPopover(
                  title: 'Hint 2',
                  description: 'Another beacon, on Card Two.',
                ),
              ),
              DriverHint(
                element: ctx.keys.card3,
                popover: const HintPopover(
                  title: 'Hint 3',
                  description: 'And a third, on Card Three.',
                ),
              ),
            ],
          ),
        );
        ctx.registerHints(h);
        h.show();
        ctx.log('hints-basic: show() with 3 hints');
      },
    ),
    Scenario(
      id: 'hints-beacon-matrix',
      title: 'Beacon placement matrix',
      description:
          'The same card gets several hints with different '
          'side × align beacon placements at once (only one is really '
          'visible per element, so this uses one hint per side).',
      run: (ctx) {
        final combos = <(Side, PopoverAlignment)>[
          (Side.top, PopoverAlignment.start),
          (Side.top, PopoverAlignment.end),
          (Side.right, PopoverAlignment.center),
          (Side.bottom, PopoverAlignment.start),
          (Side.left, PopoverAlignment.center),
        ];
        final cardKeys = ctx.keys.cards;
        final h = hints(
          HintsConfig(
            context: ctx.context,
            hints: [
              for (var i = 0; i < combos.length; i++)
                DriverHint(
                  element: cardKeys[i],
                  id: 'matrix-$i',
                  beacon: HintBeacon(side: combos[i].$1, align: combos[i].$2),
                  popover: HintPopover(
                    title: '${combos[i].$1.name}/${combos[i].$2.name}',
                    description:
                        'beacon side: ${combos[i].$1.name}, '
                        'align: ${combos[i].$2.name}',
                  ),
                ),
            ],
          ),
        );
        ctx.registerHints(h);
        h.show();
        ctx.log('hints-beacon-matrix: show() with 5 placements');
      },
    ),
    Scenario(
      id: 'hints-dismiss-restore',
      title: 'Dismiss + restoreAll',
      description:
          'Dismissing hint "1" hides it (surviving hide/show); '
          'restoreAll() brings every dismissed hint back.',
      run: (ctx) {
        final h = hints(
          HintsConfig(
            context: ctx.context,
            hints: [
              DriverHint(
                element: ctx.keys.card1,
                id: '1',
                popover: const HintPopover(title: 'Hint 1'),
                onDismiss: (element, hint, opts) =>
                    ctx.log('hints-dismiss-restore: hint 1 dismissed'),
              ),
              DriverHint(
                element: ctx.keys.card2,
                id: '2',
                popover: const HintPopover(title: 'Hint 2'),
              ),
            ],
          ),
        );
        ctx.registerHints(h);
        h.show();
        ctx.log('hints-dismiss-restore: show()');

        h.dismiss('1');
        ctx.log('hints-dismiss-restore: dismiss("1")');

        Future.delayed(const Duration(seconds: 2), () {
          h.restoreAll();
          ctx.log('hints-dismiss-restore: restoreAll() after 2s');
        });
      },
    ),
    Scenario(
      id: 'hints-tour-interplay',
      title: 'Hints hide during a tour',
      description:
          'Hints are shown first; starting a short tour hides '
          'them automatically, and they reappear once the tour ends.',
      run: (ctx) {
        final h = hints(
          HintsConfig(
            context: ctx.context,
            hints: [
              DriverHint(
                element: ctx.keys.card5,
                popover: const HintPopover(title: 'A hint'),
              ),
              DriverHint(
                element: ctx.keys.card6,
                popover: const HintPopover(title: 'Another hint'),
              ),
            ],
          ),
        );
        ctx.registerHints(h);
        h.show();
        ctx.log('hints-tour-interplay: hints shown');

        final d = driver(
          DriverConfig(
            context: ctx.context,
            steps: [
              DriveStep(
                element: ctx.keys.card1,
                popover: const DriverPopover(
                  title: 'A short tour',
                  description:
                      'Watch the hint beacons hide while this '
                      'runs, then reappear once you finish.',
                ),
              ),
              DriveStep(element: ctx.keys.card2),
            ],
            onDestroyed: (element, step, opts) =>
                ctx.log('hints-tour-interplay: tour ended, hints restored'),
          ),
        );
        ctx.registerDriver(d);
        d.drive();
      },
    ),
    Scenario(
      id: 'hints-overlay-mode',
      title: 'Overlay-mode hints',
      description:
          'HintsConfig.overlay: true — opening a hint dims the '
          'page with the element cut out, like a tour step.',
      run: (ctx) {
        final h = hints(
          HintsConfig(
            context: ctx.context,
            overlay: true,
            hints: [
              DriverHint(
                element: ctx.keys.card1,
                popover: const HintPopover(
                  title: 'Overlay mode',
                  description:
                      'Opening this hint dims the rest of the '
                      'page.',
                ),
              ),
              DriverHint(
                element: ctx.keys.card2,
                popover: const HintPopover(title: 'Another overlay hint'),
              ),
            ],
          ),
        );
        ctx.registerHints(h);
        h.show();
        ctx.log('hints-overlay-mode: show(), overlay=true');
      },
    ),
  ],
);
