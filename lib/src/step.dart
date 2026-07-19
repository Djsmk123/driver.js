/// A single tour/highlight step, plus the tour-navigation resolution
/// helpers that live alongside `DriveStep` in `step.ts`: `resolveTourStep`
/// (button-list/text/progress quirks — design decision #6), the
/// `resolveNextHook`/`resolvePrevHook`/`resolveCloseHook` tap-time hook
/// lookups, and `findReachableIndex` (the skip-aware index walk that backs
/// `isFirstStep`/`isLastStep`/`hasNextStep`/`hasPreviousStep`/`getNextStep`
/// in `driver.dart`).
///
/// M3 implemented the full button/text/progress resolution but left the
/// *skip* predicate a no-op ([neverSkipStep]). M4 fills it in with
/// [shouldSkipStep] below (ported from `step.ts`'s function of the same
/// name) and threads it through every [findReachableIndex] call in this
/// file and in `driver.dart`, so reachability queries
/// (`isFirstStep`/`isLastStep`/`hasNextStep`/`hasPreviousStep`/
/// `getNextStep`) and the tour's own skip-walk (`driver.dart`'s `_drive`)
/// agree on what counts as reachable. [neverSkipStep] is kept only as a
/// building block for tests/callers that explicitly want a plain bounds
/// check.
library;

import 'config.dart';
import 'context.dart';
import 'popover.dart';
import 'utils.dart';

/// The literal driver.js default for `Popover["progressText"]`
/// (`"{{current}} of {{total}}"` in `step.ts`), interpolated last by
/// [resolveTourStep] once every other field is resolved.
const String kDefaultProgressText = '{{current}} of {{total}}';

/// One step of a tour, or the argument to `Driver.highlight()` for a
/// single, tour-less highlight.
class DriveStep {
  const DriveStep({
    this.element,
    this.popover,
    this.disableActiveInteraction,
    this.advanceOnClick,
    this.skipMissingElement,
    this.waitForElement,
    this.data,
    this.onHighlightStarted,
    this.onHighlighted,
    this.onDeselected,
  });

  /// The element to highlight: a [GlobalKey], a [BuildContext], a zero-arg
  /// function returning either of those (or `null`), or `null` itself.
  /// Resolved via `resolveTargetContext` in `utils.dart`. `null` produces
  /// an element-less "centered" step, mirroring driver.js's dummy
  /// zero-size div mounted at the viewport center for a selector that
  /// resolves to nothing (see `highlight.dart`).
  final Object? element;

  /// Per-step popover configuration. `null` means this step highlights
  /// without ever showing a popover (driver.js's bare, buttonless
  /// `highlight()` usage — see design decision #6). Within a tour, every
  /// step gets *some* popover once [resolveTourStep] runs — even one that
  /// started `null` — mirroring `resolveTourStep`'s `step.popover || {}`.
  final DriverPopover? popover;

  /// Overrides `DriverConfig.disableActiveInteraction` for this step.
  final bool? disableActiveInteraction;

  /// Overrides `DriverConfig.advanceOnClick` for this step. Wiring this up
  /// to actually advance a tour is M4 scope.
  final bool? advanceOnClick;

  /// Overrides `DriverConfig.skipMissingElement` for this step. Only
  /// meaningful once tour navigation can really skip steps — M4 scope; see
  /// this file's top-level doc comment.
  final bool? skipMissingElement;

  /// Overrides `DriverConfig.waitForElement` for this step. Wired up in
  /// M4 alongside `waitForElement` polling.
  final Duration? waitForElement;

  /// Arbitrary user data threaded through to hooks via `DriveStep`, mirrors
  /// `step.ts`'s `data` field.
  final Map<String, Object?>? data;

  final DriverHook? onHighlightStarted;
  final DriverHook? onHighlighted;
  final DriverHook? onDeselected;

  /// Returns a copy with [popover] replaced (or kept, if omitted). Used by
  /// [resolveTourStep]/[applyHighlightDefaults] to rebuild a step around a
  /// freshly-resolved popover without repeating every other field by hand
  /// — those are the only fields resolution ever touches.
  DriveStep copyWith({DriverPopover? popover}) => DriveStep(
    element: element,
    popover: popover ?? this.popover,
    disableActiveInteraction: disableActiveInteraction,
    advanceOnClick: advanceOnClick,
    skipMissingElement: skipMissingElement,
    waitForElement: waitForElement,
    data: data,
    onHighlightStarted: onHighlightStarted,
    onHighlighted: onHighlighted,
    onDeselected: onDeselected,
  );
}

/// Skip predicate signature passed to [findReachableIndex]. M4 will supply
/// a real one (`shouldSkipStep`, driven by `skipMissingElement`); M3 only
/// ever passes [neverSkipStep].
typedef SkipStepPredicate = bool Function(DriveStep step);

/// The always-false skip predicate M3 wired everywhere a real one now goes
/// (see this file's top-level doc comment) — kept for tests/callers that
/// want a plain bounds check with no skip-awareness at all.
bool neverSkipStep(DriveStep step) => false;

/// Whether [step] should be skipped during tour navigation, ported from
/// `shouldSkipStep` in `step.ts`. Driven by the effective
/// `skipMissingElement` (step overrides config) — with that off, or for an
/// intentionally element-less step (`step.element == null`, driver.js's
/// "centered" step, never a *missing* element), this is always `false`.
/// Only a *specified but currently unresolvable* element gets skipped, and
/// only when `skipMissingElement` allows it — the same live-tree resolution
/// `resolveTargetContext` performs everywhere else, so a step that mounts
/// later stops being "skippable" without any extra bookkeeping.
bool shouldSkipStep(DriverContext ctx, DriveStep step) {
  final skip = step.skipMissingElement ?? ctx.config.skipMissingElement;
  if (!skip || step.element == null) return false;
  return resolveTargetContext(step.element) == null;
}

/// The index navigation would actually land on, starting at [fromIndex]
/// (inclusive) and walking [steps] in [direction] (`1` forward, `-1`
/// backward) past any step [shouldSkip] rejects. Returns `null` if the walk
/// runs off either end without finding a reachable index. Ported from
/// `findReachableIndex` in `step.ts`; every first/last-step decision in
/// `driver.dart` goes through this so the "done" button and the tour's real
/// end always agree.
int? findReachableIndex(
  List<DriveStep> steps,
  int fromIndex,
  int direction,
  SkipStepPredicate shouldSkip,
) {
  for (var i = fromIndex; i >= 0 && i < steps.length; i += direction) {
    if (!shouldSkip(steps[i])) return i;
  }
  return null;
}

/// Default button actions supplied by the tour itself — which alone knows
/// how to navigate and destroy — used by [resolveTourStep] whenever a step
/// and the config both leave a hook unset. Mirrors `TourStepDefaults` in
/// `step.ts`.
class TourStepDefaults {
  const TourStepDefaults({
    required this.onNextClick,
    required this.onPrevClick,
    required this.onCloseClick,
  });

  final DriverHook onNextClick;
  final DriverHook onPrevClick;
  final DriverHook onCloseClick;
}

/// On the final reachable step the next button acts as the done button, so
/// a dedicated `onDoneClick` (step popover, then config) takes precedence
/// over `onNextClick` — this is the handler-side counterpart of
/// `nextBtnText` swapping to `doneBtnText`. Always resolved fresh against
/// live state/config (never baked into a closure ahead of time) so a
/// `setConfig`/navigation between render and a later tap is picked up.
/// Ported from `resolveNextHook` in `step.ts`.
DriverHook? resolveNextHook(DriverContext ctx, DriveStep? step) {
  final activeIndex = ctx.state.activeIndex;
  final steps = ctx.config.steps ?? const <DriveStep>[];
  final isLastStep =
      activeIndex != null &&
      findReachableIndex(
            steps,
            activeIndex + 1,
            1,
            (s) => shouldSkipStep(ctx, s),
          ) ==
          null;

  final onDoneClick = step?.popover?.onDoneClick ?? ctx.config.onDoneClick;
  if (isLastStep && onDoneClick != null) return onDoneClick;

  return step?.popover?.onNextClick ?? ctx.config.onNextClick;
}

/// Ported from `resolvePrevHook` in `step.ts`.
DriverHook? resolvePrevHook(DriverContext ctx, DriveStep? step) =>
    step?.popover?.onPrevClick ?? ctx.config.onPrevClick;

/// Ported from `resolveCloseHook` in `step.ts`.
DriverHook? resolveCloseHook(DriverContext ctx, DriveStep? step) =>
    step?.popover?.onCloseClick ?? ctx.config.onCloseClick;

/// Which of the tour's base buttons (`next`, `previous`, `close` when
/// `allowClose`) survive a `showButtons` filter, applying design decision
/// #6's quirk verbatim: an empty *step*-level list wins outright (shows
/// none), but an empty *config*-level list — reached only when the step
/// didn't set one at all — keeps every base button (the JS `!length`
/// check), rather than the two being treated identically.
List<DriverButton> _resolveShowButtons({
  required List<DriverButton>? stepShowButtons,
  required List<DriverButton> configShowButtons,
  required bool allowClose,
}) {
  final base = [
    DriverButton.next,
    DriverButton.previous,
    if (allowClose) DriverButton.close,
  ];

  if (stepShowButtons != null) {
    if (stepShowButtons.isEmpty) return const <DriverButton>[];
    return base.where(stepShowButtons.contains).toList();
  }

  if (configShowButtons.isEmpty) return base;
  return base.where(configShowButtons.contains).toList();
}

/// Resolves tour step [stepIndex] into the [DriveStep] that ends up in
/// state and that the lifecycle hooks receive — not just what gets
/// rendered. Ported from `resolveTourStep` in `step.ts`: computes the
/// button list, the `nextBtnText` → `doneBtnText` swap on the last
/// reachable step, `disableButtons` gaining `previous` on the first
/// reachable step (shadowing any global `disableButtons` during tours
/// unless the step set its own), `showProgress`, and the
/// `{{current}}/{{total}}` progress-text interpolation (applied last, after
/// every other field is settled). [defaults] supplies the fallback
/// next/previous/close actions the tour itself defines; a step or config
/// hook always wins over them.
DriveStep resolveTourStep(
  DriverContext ctx,
  int stepIndex,
  TourStepDefaults defaults,
) {
  final steps = ctx.config.steps ?? const <DriveStep>[];
  final step = steps[stepIndex];
  final popover = step.popover ?? const DriverPopover();

  bool skip(DriveStep s) => shouldSkipStep(ctx, s);
  final hasNextStep = findReachableIndex(steps, stepIndex + 1, 1, skip) != null;
  final hasPreviousStep =
      findReachableIndex(steps, stepIndex - 1, -1, skip) != null;

  final doneBtnText = popover.doneBtnText ?? ctx.config.doneBtnText ?? 'Done';
  final showProgress = popover.showProgress ?? ctx.config.showProgress;
  final progressTemplate =
      popover.progressText ?? ctx.config.progressText ?? kDefaultProgressText;
  final progressText = progressTemplate
      .replaceAll('{{current}}', '${stepIndex + 1}')
      .replaceAll('{{total}}', '${steps.length}');

  final showButtons = _resolveShowButtons(
    stepShowButtons: popover.showButtons,
    configShowButtons: ctx.config.showButtons,
    allowClose: ctx.config.allowClose,
  );
  final disableButtons =
      popover.disableButtons ??
      (!hasPreviousStep
          ? const <DriverButton>[DriverButton.previous]
          : const <DriverButton>[]);

  // A step-level `nextBtnText` always wins; only when the step never set
  // one does the last-reachable-step done-text swap apply.
  final nextBtnText =
      popover.nextBtnText ?? (!hasNextStep ? doneBtnText : null);

  final onNextClick = popover.onNextClick ?? defaults.onNextClick;
  final onPrevClick = popover.onPrevClick ?? defaults.onPrevClick;
  final onCloseClick = popover.onCloseClick ?? defaults.onCloseClick;

  return step.copyWith(
    popover: DriverPopover(
      title: popover.title,
      description: popover.description,
      titleWidget: popover.titleWidget,
      descriptionWidget: popover.descriptionWidget,
      side: popover.side,
      align: popover.align,
      showButtons: showButtons,
      disableButtons: disableButtons,
      showProgress: showProgress,
      progressText: progressText,
      nextBtnText: nextBtnText,
      prevBtnText: popover.prevBtnText,
      doneBtnText: popover.doneBtnText,
      theme: popover.theme,
      popoverBuilder: popover.popoverBuilder,
      onPopoverRender: popover.onPopoverRender,
      onNextClick: onNextClick,
      onPrevClick: onPrevClick,
      onCloseClick: onCloseClick,
      onDoneClick: popover.onDoneClick,
    ),
  );
}

/// Wraps a bare, tour-less `Driver.highlight(step)` call's popover with
/// driver.js's buttonless/no-progress defaults (design decision #6):
/// `showButtons: []`, `showProgress: false`, `progressText: ''`, with
/// anything the step itself set on top winning. A `null` `step.popover`
/// passes through unchanged — no popover at all. Mirrors the `highlight:`
/// entry of `driver.ts`'s public API object.
DriveStep applyHighlightDefaults(DriveStep step) {
  final popover = step.popover;
  if (popover == null) return step;

  return step.copyWith(
    popover: DriverPopover(
      title: popover.title,
      description: popover.description,
      titleWidget: popover.titleWidget,
      descriptionWidget: popover.descriptionWidget,
      side: popover.side,
      align: popover.align,
      showButtons: popover.showButtons ?? const <DriverButton>[],
      disableButtons: popover.disableButtons,
      showProgress: popover.showProgress ?? false,
      progressText: popover.progressText ?? '',
      nextBtnText: popover.nextBtnText,
      prevBtnText: popover.prevBtnText,
      doneBtnText: popover.doneBtnText,
      theme: popover.theme,
      popoverBuilder: popover.popoverBuilder,
      onPopoverRender: popover.onPopoverRender,
      onNextClick: popover.onNextClick,
      onPrevClick: popover.onPrevClick,
      onCloseClick: popover.onCloseClick,
      onDoneClick: popover.onDoneClick,
    ),
  );
}
