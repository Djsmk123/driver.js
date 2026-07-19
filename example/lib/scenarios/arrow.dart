/// Arrow placement scenarios: the 12 side×align combination matrix
/// (stepped through as a tour), a couple of forced-fallback "flip" cases,
/// and the centered/no-arrow case.
library;

import 'package:driverjs/driverjs.dart';

import '../scenario.dart';
import '../stage_page.dart';

List<DriveStep> _matrixSteps(StageKeys keys) {
  final combos = <(Side, PopoverAlignment)>[
    for (final side in Side.values)
      for (final align in PopoverAlignment.values) (side, align),
  ];
  return [
    for (final combo in combos)
      DriveStep(
        element: keys.card3,
        popover: DriverPopover(
          title: '${combo.$1.name} / ${combo.$2.name}',
          description:
              'side: Side.${combo.$1.name}, '
              'align: PopoverAlignment.${combo.$2.name}',
          side: combo.$1,
          align: combo.$2,
        ),
      ),
  ];
}

final arrowGroup = ScenarioGroup(
  title: 'Arrow positioning',
  scenarios: [
    Scenario(
      id: 'arrow-matrix',
      title: '12-position matrix',
      description:
          'Steps through every side × align combination against '
          'the same card — use Next to cycle.',
      run: (ctx) {
        final d = driver(
          DriverConfig(context: ctx.context, steps: _matrixSteps(ctx.keys)),
        );
        ctx.registerDriver(d);
        d.drive();
        ctx.log('arrow-matrix: started 12-step matrix tour');
      },
    ),
    Scenario(
      id: 'arrow-flip-top',
      title: 'Flip case (top edge)',
      description:
          'Preferred side "top" against the page header, which '
          'has no room above it — the popover falls back and the arrow '
          'flips accordingly.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.header,
            popover: const DriverPopover(
              title: 'Flip: top requested',
              description:
                  'Preferred side is top, but there is no room '
                  'above the header, so the arrow flips.',
              side: Side.top,
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('arrow-flip-top: side=top requested against header');
      },
    ),
    Scenario(
      id: 'arrow-flip-bottom',
      title: 'Flip case (bottom edge)',
      description:
          'Preferred side "bottom" against a near-bottom-of-page '
          'element, forcing a fallback and arrow flip.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          DriveStep(
            element: ctx.keys.belowFold,
            popover: const DriverPopover(
              title: 'Flip: bottom requested',
              description:
                  'Preferred side is bottom, which may not fit — '
                  'watch the arrow track the fallback side.',
              side: Side.bottom,
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('arrow-flip-bottom: side=bottom requested against belowFold');
      },
    ),
    Scenario(
      id: 'arrow-centered-no-arrow',
      title: 'Centered, no arrow',
      description:
          'An element-less popover — centered in the viewport '
          'with the arrow hidden entirely.',
      run: (ctx) {
        final d = driver(DriverConfig(context: ctx.context));
        ctx.registerDriver(d);
        d.highlight(
          const DriveStep(
            element: null,
            popover: DriverPopover(
              title: 'No arrow here',
              description:
                  'Centered popovers have nothing to point at, '
                  'so the arrow is hidden.',
              showButtons: [DriverButton.close],
            ),
          ),
        );
        ctx.log('arrow-centered-no-arrow: element=null');
      },
    ),
  ],
);
