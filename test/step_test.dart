// Pure unit tests for `step.dart`'s tour-navigation resolution helpers
// (design decision #6 in the plan): `resolveTourStep`'s button-list/text/
// progress quirks and `findReachableIndex`'s skip-aware index walk. No
// widgets are pumped here — `DriverContext` is exercised directly against a
// `DriverConfig`, since none of this logic touches rendering.

import 'package:driverjs/src/config.dart';
import 'package:driverjs/src/context.dart';
import 'package:driverjs/src/popover.dart';
import 'package:driverjs/src/step.dart';
import 'package:flutter_test/flutter_test.dart';

TourStepDefaults _noopDefaults() => TourStepDefaults(
  onNextClick: (_, _, _) {},
  onPrevClick: (_, _, _) {},
  onCloseClick: (_, _, _) {},
);

DriverContext _ctxFor(DriverConfig config) => DriverContext(config);

void main() {
  group('findReachableIndex', () {
    test('walks forward to the next in-bounds index', () {
      final steps = List.generate(4, (_) => const DriveStep());
      expect(findReachableIndex(steps, 1, 1, neverSkipStep), 1);
      expect(findReachableIndex(steps, 2, 1, neverSkipStep), 2);
    });

    test('walks backward to the previous in-bounds index', () {
      final steps = List.generate(4, (_) => const DriveStep());
      expect(findReachableIndex(steps, 2, -1, neverSkipStep), 2);
      expect(findReachableIndex(steps, 0, -1, neverSkipStep), 0);
    });

    test('returns null past either end', () {
      final steps = List.generate(3, (_) => const DriveStep());
      expect(findReachableIndex(steps, 3, 1, neverSkipStep), isNull);
      expect(findReachableIndex(steps, -1, -1, neverSkipStep), isNull);
    });

    test('a real skip predicate skips past rejected steps', () {
      // Distinct `data` maps (rather than identical `const DriveStep()`s)
      // so a skip predicate can actually tell the steps apart by identity.
      final steps = List.generate(4, (i) => DriveStep(data: {'index': i}));
      bool skipIndexOne(DriveStep step) => step.data!['index'] == 1;
      expect(findReachableIndex(steps, 0, 1, skipIndexOne), 0);
      expect(findReachableIndex(steps, 1, 1, skipIndexOne), 2);
    });
  });

  group('resolveTourStep button-list quirks', () {
    test('an empty config-level showButtons keeps every base button '
        '(the JS "!length" check)', () {
      final steps = [const DriveStep(), const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps, showButtons: const []);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 1, _noopDefaults());

      expect(resolved.popover!.showButtons, [
        DriverButton.next,
        DriverButton.previous,
        DriverButton.close,
      ]);
    });

    test('an empty step-level showButtons wins outright (shows none)', () {
      final steps = [
        const DriveStep(popover: DriverPopover(showButtons: [])),
        const DriveStep(),
        const DriveStep(),
      ];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.showButtons, isEmpty);
    });

    test('a non-empty step-level showButtons filters the base list', () {
      final steps = [
        const DriveStep(
          popover: DriverPopover(showButtons: [DriverButton.next]),
        ),
        const DriveStep(),
      ];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.showButtons, [DriverButton.next]);
    });

    test('close is dropped from the base list when allowClose is false', () {
      final steps = [const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps, allowClose: false);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.showButtons, [
        DriverButton.next,
        DriverButton.previous,
      ]);
    });
  });

  group('resolveTourStep nextBtnText -> doneBtnText swap', () {
    test('the last reachable step swaps nextBtnText to doneBtnText', () {
      final steps = [const DriveStep(), const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps, doneBtnText: 'All done');
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 2, _noopDefaults());

      expect(resolved.popover!.nextBtnText, 'All done');
    });

    test('a non-last step leaves nextBtnText unset (widget default wins)', () {
      final steps = [const DriveStep(), const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.nextBtnText, isNull);
    });

    test("a step's own explicit nextBtnText wins over the done-text swap", () {
      final steps = [
        const DriveStep(),
        const DriveStep(popover: DriverPopover(nextBtnText: 'Finish up')),
      ];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 1, _noopDefaults());

      expect(resolved.popover!.nextBtnText, 'Finish up');
    });

    test('doneBtnText falls back to the literal "Done"', () {
      final steps = [const DriveStep()];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.nextBtnText, 'Done');
    });
  });

  group('resolveTourStep disableButtons gains previous on the first step', () {
    test('the first reachable step disables previous', () {
      final steps = [const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.disableButtons, [DriverButton.previous]);
    });

    test('a later step has no auto-disabled buttons', () {
      final steps = [const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 1, _noopDefaults());

      expect(resolved.popover!.disableButtons, isEmpty);
    });

    test("shadows a global config-level disableButtons that doesn't apply", () {
      final steps = [const DriveStep(), const DriveStep()];
      final config = DriverConfig(
        steps: steps,
        disableButtons: const [DriverButton.close],
      );
      final ctx = _ctxFor(config);

      // Step 1 isn't first, so the tour computes an empty disableButtons
      // list — the config-level `disableButtons: [close]` never applies
      // to tour steps at all, only a step's own popover.disableButtons
      // would.
      final resolved = resolveTourStep(ctx, 1, _noopDefaults());

      expect(resolved.popover!.disableButtons, isEmpty);
    });

    test("a step's own disableButtons replaces the computed list", () {
      final steps = [
        const DriveStep(
          popover: DriverPopover(disableButtons: [DriverButton.close]),
        ),
        const DriveStep(),
      ];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      // Step 0 is first (would normally disable previous), but the step's
      // own explicit list wins outright.
      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.disableButtons, [DriverButton.close]);
    });
  });

  group('resolveTourStep progress-text interpolation', () {
    test('the default template interpolates {{current}}/{{total}}', () {
      final steps = [const DriveStep(), const DriveStep(), const DriveStep()];
      final config = DriverConfig(steps: steps);
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 1, _noopDefaults());

      expect(resolved.popover!.progressText, '2 of 3');
    });

    test('a custom config-level template interpolates the same way', () {
      final steps = [const DriveStep(), const DriveStep()];
      final config = DriverConfig(
        steps: steps,
        progressText: '{{current}}/{{total}}',
      );
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.progressText, '1/2');
    });

    test('a step-level template wins over the config-level one', () {
      final steps = [
        const DriveStep(
          popover: DriverPopover(progressText: 'Step {{current}}'),
        ),
      ];
      final config = DriverConfig(steps: steps, progressText: 'ignored');
      final ctx = _ctxFor(config);

      final resolved = resolveTourStep(ctx, 0, _noopDefaults());

      expect(resolved.popover!.progressText, 'Step 1');
    });
  });

  group('applyHighlightDefaults (bare, tour-less highlight())', () {
    test('a null popover stays null', () {
      const step = DriveStep(popover: null);
      expect(applyHighlightDefaults(step).popover, isNull);
    });

    test('a set popover defaults to buttonless, no progress, empty progress '
        'text', () {
      const step = DriveStep(
        popover: DriverPopover(title: 'Hi', description: 'There'),
      );
      final resolved = applyHighlightDefaults(step).popover!;

      expect(resolved.showButtons, isEmpty);
      expect(resolved.showProgress, isFalse);
      expect(resolved.progressText, '');
      expect(resolved.title, 'Hi');
      expect(resolved.description, 'There');
    });

    test("the step's own explicit fields win over the buttonless defaults", () {
      const step = DriveStep(
        popover: DriverPopover(
          showButtons: [DriverButton.close],
          showProgress: true,
        ),
      );
      final resolved = applyHighlightDefaults(step).popover!;

      expect(resolved.showButtons, [DriverButton.close]);
      expect(resolved.showProgress, isTrue);
    });
  });
}
