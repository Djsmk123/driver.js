/// The public `Driver` API and the `driver()` factory, ported from
/// `driver.ts`. M3 lands the full tour-navigation surface: `drive`,
/// `moveNext`/`movePrevious`/`moveTo`, `getPreviousStep`/`getPreviousElement`
/// (previously-*visited*, not `index - 1`), the reachability queries
/// (`isFirstStep`/`isLastStep`/`hasNextStep`/`hasPreviousStep`/`getNextStep`,
/// all backed by `findReachableIndex` in `step.dart`), `setConfig`'s
/// wholesale-replace and `setSteps`'s state-reset-keep-config semantics, and
/// `destroy`'s `onDestroyStarted`-interception + focus-restore teardown
/// (design decision #9). Keyboard routing (design decision #10) lives here
/// too, as the handlers `overlay_widget.dart`'s `DriverOverlay` calls into.
///
/// M4 fills in what M3 left as stubs: `waitForElement` polling (a
/// post-frame poll of `resolveTargetContext` plus a cancellable `Timer` for
/// the timeout — the DOM `MutationObserver` `waitForStepElement` in
/// `driver.ts` uses has no Flutter analogue, so this polls instead), the
/// `shouldSkipStep`-driven skip walk inside `_drive` (design decision #9,
/// including its forward-destroys/backward-stays-put asymmetry),
/// `advanceOnClick`'s hole-tap handler, and the passive per-frame rect
/// watcher that's the other half of design decision #5 (the metrics
/// observer above only catches resize; this catches scroll, since the
/// overlay entry never receives the app's `ScrollNotification`s).
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'context.dart';
import 'events.dart';
import 'highlight.dart';
import 'overlay_widget.dart';
import 'state.dart';
import 'step.dart';
import 'theme.dart';
import 'utils.dart';

/// The public driver.js-mirroring API. See the plan's public API sketch
/// for the full shape; every method below is implemented as of M3.
abstract class Driver {
  /// Starts (or restarts) a tour at [stepIndex]. Out-of-range (including no
  /// configured steps at all) tears the driver down instead, mirroring
  /// `drive()` falling through to `destroy()` in `driver.ts`.
  void drive([int stepIndex = 0]);

  /// Highlights a single element, independent of any tour. Mounts the
  /// overlay (resolving a [BuildContext] to attach it to per design
  /// decision #1) if it isn't already, then animates the stage to [step]'s
  /// element. Unlike [drive], this never captures focus for restore and its
  /// popover (if any) gets driver.js's bare-highlight defaults —
  /// buttonless, no progress (design decision #6).
  void highlight(DriveStep step);

  /// Advances to the next tour step, or [destroy]s (with the
  /// `onDestroyStarted` hook able to intercept) once past the last
  /// reachable one.
  void moveNext();

  /// Returns to the previous tour step, or [destroy]s once past the first
  /// reachable one. Note this differs from what ArrowLeft does at the
  /// keyboard layer, which no-ops instead on the first step (design
  /// decision #10) — that's a keyboard-only guard, not something
  /// [movePrevious] itself does, matching `driver.ts`.
  void movePrevious();

  /// Jumps straight to tour step [index] (not reachability-walked — an
  /// out-of-range index [destroy]s the same way [moveNext]/[movePrevious]
  /// do past either end).
  void moveTo(int index);

  /// Whether a reachable next tour step exists.
  bool hasNextStep();

  /// Whether a reachable previous tour step exists.
  bool hasPreviousStep();

  /// Whether the active step is the tour's first reachable step.
  bool isFirstStep();

  /// Whether the active step is the tour's last reachable step.
  bool isLastStep();

  /// The step passed to the most recent `highlight()`/`drive()` call.
  DriveStep? getActiveStep();

  /// The element passed to the most recent `highlight()`/`drive()` call.
  BuildContext? getActiveElement();

  /// The previously *visited* step — not simply `index - 1`, which would be
  /// wrong the moment a skip walk or `moveTo` jump is involved. Tracked as
  /// the step that was actually settled/active immediately before the
  /// current one, the same way `previousStep` is populated in
  /// `transferHighlight` (`highlight.dart`).
  DriveStep? getPreviousStep();

  /// The previously *visited* element — see [getPreviousStep].
  BuildContext? getPreviousElement();

  /// The next reachable step a tour would move to, or `null` outside a tour
  /// or on the last reachable step.
  DriveStep? getNextStep();

  /// The active tour step index, or `null` outside a tour.
  int? getActiveIndex();

  /// The driver's mutable runtime state.
  DriverState getState();

  /// The driver's current config.
  DriverConfig getConfig();

  /// Replaces the config wholesale (design decision #9's "wholesale
  /// replace", not a merge) — re-applies every `DriverConfig` default
  /// rather than keeping old field values [config] doesn't set.
  void setConfig(DriverConfig config);

  /// Replaces the tour's steps, resetting navigation state (active index,
  /// visit history, …) but keeping the rest of the current config as-is —
  /// mirrors `setSteps` in `driver.ts` (`ctx.resetState()` then
  /// `ctx.setConfig({...ctx.getConfig(), steps})`).
  void setSteps(List<DriveStep> steps);

  /// Requests a frame-coalesced re-sync of the stage to the active
  /// element's current rect (`RefreshScheduler` in `events.dart`).
  void refresh();

  /// Whether the overlay is currently mounted.
  bool isActive();

  /// Tears down the overlay and resets state. Unlike every *internal* path
  /// that can close the driver (Esc, the popover's `x`, an overlay-click
  /// close, `moveNext`/`movePrevious`/`moveTo`/`drive` past either end),
  /// this public, parameterless method always skips `onDestroyStarted` —
  /// mirrors `destroy: () => destroy(false)` in `driver.ts`. Those other,
  /// user-initiated paths pass `withHook: true` internally so
  /// `config.onDestroyStarted` gets a chance to intercept the close (a
  /// confirm-on-exit pattern); the hook has to call `driver.destroy()`
  /// itself to actually tear down.
  void destroy();
}

/// Creates a [Driver], mirroring the `driver(options)` factory in
/// `driver.ts`.
Driver driver([DriverConfig config = const DriverConfig()]) =>
    _DriverImpl(config);

class _DriverImpl implements Driver {
  _DriverImpl(DriverConfig config) : _ctx = DriverContext(config) {
    _ctx.driver = this;
    _ctx.requestUserClose = () => _destroyInternal(withHook: true);
  }

  final DriverContext _ctx;

  final GlobalKey<DriverOverlayState> _overlayKey =
      GlobalKey<DriverOverlayState>();
  OverlayEntry? _entry;
  RefreshScheduler? _refreshScheduler;
  DriverMetricsObserver? _metricsObserver;

  @override
  void highlight(DriveStep step) {
    final resolvedStep = applyHighlightDefaults(step);
    final mountContext = _resolveMountContext(resolvedStep);
    if (mountContext == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'driverjs: could not resolve a BuildContext to mount the overlay.',
        ),
        ErrorDescription(
          'Pass `context:` in DriverConfig, or make sure the step\'s '
          '`element` resolves to a mounted widget before calling '
          'highlight().',
        ),
      ]);
    }

    _ensureMounted(mountContext);

    // Geometry can only be read once the overlay entry has actually built
    // and laid out, which happens after this frame's build/layout/paint —
    // so the real work is deferred to a post-frame callback rather than
    // done inline.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _performHighlight(resolvedStep),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void drive([int stepIndex = 0]) => _drive(stepIndex);

  /// The real implementation behind [drive]. [hasWaitedForElement] is the
  /// Dart equivalent of `driver.ts`'s `drive(stepIndex, hasWaitedForElement)`
  /// second argument: `true` only on the recursive call
  /// [_waitForStepElement] makes once a wait settles (by resolution or by
  /// timeout), so that call never re-enters the wait branch below a second
  /// time for the same step.
  void _drive(int stepIndex, {bool hasWaitedForElement = false}) {
    _cancelPendingWait();

    final steps = _ctx.config.steps;
    if (steps == null ||
        steps.isEmpty ||
        stepIndex < 0 ||
        stepIndex >= steps.length) {
      _destroyInternal(withHook: true);
      return;
    }

    final currentStep = steps[stepIndex];

    // `waitForElement`: a step whose element is specified but not yet
    // resolvable gets a grace period before falling through to the usual
    // missing-element handling (skip walk, or a centered dummy highlight).
    // This returns *before* touching the overlay at all — whatever was
    // highlighted before (if anything) stays highlighted while waiting,
    // mirroring `drive()`'s early return in driver.ts.
    final waitTimeout =
        currentStep.waitForElement ?? _ctx.config.waitForElement;
    if (!hasWaitedForElement &&
        waitTimeout > Duration.zero &&
        currentStep.element != null &&
        resolveTargetContext(currentStep.element) == null) {
      _waitForStepElement(stepIndex, currentStep, waitTimeout);
      return;
    }

    // Skip walk (design decision #9): direction is resolved against
    // whatever `activeIndex` *was* before this call (not yet overwritten
    // below), exactly like `stepIndex < activeIndex` in driver.ts — so a
    // backward `movePrevious()`/keyboard-left landing on a skippable step
    // keeps walking backward, and a forward one keeps walking forward.
    // Ported as a direct step-by-step recursion (not `findReachableIndex`)
    // to match driver.ts exactly: each intermediate step gets its own
    // `_drive` call, so it goes through the wait-for-element branch above
    // too, rather than being silently jumped over.
    if (shouldSkipStep(_ctx, currentStep)) {
      final activeIndex = _ctx.state.activeIndex;
      final direction = (activeIndex != null && stepIndex < activeIndex)
          ? -1
          : 1;
      final targetIndex = stepIndex + direction;
      if (targetIndex >= 0 && targetIndex < steps.length) {
        _drive(targetIndex);
      } else if (direction == 1) {
        _destroyInternal(withHook: true);
      }
      // Walking backward off the start (direction == -1, no target index
      // left): stay put — no destroy, no state change. This asymmetry is
      // deliberate, not a bug; see design decision #9.
      return;
    }

    // Mount resolution only matters the first time: once the overlay entry
    // exists, later steps (including an element-less "centered" one reached
    // via a skip walk or a `waitForElement` timeout) don't need a resolvable
    // element or an explicit `config.context` of their own to navigate to.
    if (_entry == null) {
      final mountContext = _resolveMountContext(currentStep);
      if (mountContext == null) {
        throw FlutterError.fromParts([
          ErrorSummary(
            'driverjs: could not resolve a BuildContext to mount the '
            'overlay.',
          ),
          ErrorDescription(
            'Pass `context:` in DriverConfig, or make sure step $stepIndex\'s '
            '`element` resolves to a mounted widget before calling drive().',
          ),
        ]);
      }
      _ensureMounted(mountContext);
    }

    // Captured fresh on every `drive()` call — see `DriverState
    // .focusToRestore`'s doc comment for why this isn't just captured once
    // at tour start.
    _ctx.state.focusToRestore = FocusManager.instance.primaryFocus;
    _ctx.state.activeIndex = stepIndex;

    final defaults = TourStepDefaults(
      onNextClick: (element, step, opts) {
        final nextIndex = findReachableIndex(
          steps,
          stepIndex + 1,
          1,
          _shouldSkip,
        );
        if (nextIndex != null) {
          _drive(nextIndex);
        } else {
          _destroyInternal(withHook: true);
        }
      },
      onPrevClick: (element, step, opts) => _drive(stepIndex - 1),
      onCloseClick: (element, step, opts) => _destroyInternal(withHook: true),
    );

    final resolvedStep = resolveTourStep(_ctx, stepIndex, defaults);

    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _performHighlight(resolvedStep),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// [shouldSkipStep] bound to this driver's context — the predicate
  /// [findReachableIndex] is called with everywhere reachability matters
  /// (`moveNext`/`movePrevious`/`hasNextStep`/`hasPreviousStep`/
  /// `getNextStep` below; `_drive`'s own skip walk above is a direct
  /// step-by-step recursion instead, to match driver.ts's recursion
  /// exactly — see its comment).
  bool _shouldSkip(DriveStep step) => shouldSkipStep(_ctx, step);

  void _performHighlight(DriveStep step) {
    final overlay = _overlayKey.currentState;
    if (overlay == null) {
      // The entry hasn't finished building yet (e.g. it was only just
      // inserted this same frame, ahead of the callback above) — retry on
      // the next frame rather than silently dropping the highlight.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _performHighlight(step),
      );
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    transferHighlight(_ctx, step, overlay);
  }

  BuildContext? _resolveMountContext(DriveStep step) {
    final configContext = _ctx.config.context;
    if (configContext != null && configContext.mounted) {
      return configContext;
    }
    return resolveTargetContext(step.element);
  }

  void _ensureMounted(BuildContext mountContext) {
    if (_entry != null) return;

    final overlayState = Overlay.of(mountContext, rootOverlay: true);
    final theme = _ctx.config.theme ?? const DriverTheme();

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: DriverOverlay(
            key: _overlayKey,
            initialStageRect: Rect.zero,
            theme: theme,
            disableActiveInteraction: _ctx.config.disableActiveInteraction,
            fadeInDuration: _ctx.config.duration,
            animateFadeIn: _ctx.config.animate,
            onOverlayTap: _handleOverlayTap,
            onHoleTap: _handleHoleTap,
            allowKeyboardControl: _ctx.config.allowKeyboardControl,
            onEscape: _handleEscape,
            onArrowRight: _handleArrowRight,
            onArrowLeft: _handleArrowLeft,
          ),
        );
      },
    );
    overlayState.insert(_entry!);
    _ctx.state.isInitialized = true;

    _refreshScheduler = RefreshScheduler(_handleRefresh);
    _metricsObserver = DriverMetricsObserver(_refreshScheduler!);
    WidgetsBinding.instance.addObserver(_metricsObserver!);

    _armRectWatcher();
  }

  void _handleRefresh() {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    refreshActiveHighlight(_ctx, overlay);
  }

  /// The other half of design decision #5 (`DriverMetricsObserver` above
  /// only catches resize): a passive, self-re-arming post-frame callback
  /// that compares the active element's *current* rect against
  /// `state.activeStagePosition` (the stage's last-known rect — kept in
  /// sync by both a settled highlight transition and by
  /// [refreshActiveHighlight] itself) every time a frame renders for
  /// *any* reason, and snaps the stage (via [refreshActiveHighlight]) only
  /// when they differ. This is what catches the app scrolling out from
  /// under an active highlight — the overlay entry never receives the
  /// app's `ScrollNotification`s, so there's no push-based signal to react
  /// to; comparing rects on every rendered frame is the only way left to
  /// notice.
  ///
  /// Deliberately calls neither `ensureVisualUpdate()` nor any other
  /// frame-forcing API — re-arming via `addPostFrameCallback` alone means
  /// this rides whatever frames the app already produces (scrolling,
  /// ticker animations, unrelated `setState`s) instead of scheduling extra
  /// ones of its own; an idle app with nothing changing simply stops
  /// getting called until something else wakes it up again. Stops
  /// re-arming once [_entry] goes `null` (the driver was destroyed).
  void _armRectWatcher() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_entry == null) return;
      _checkRectChanged();
      _armRectWatcher();
    });
  }

  void _checkRectChanged() {
    if (_ctx.state.transitionToken != null) {
      // The stage-chase ticker already re-reads the live target rect every
      // tick while a transition is in flight (design decision #3) — a
      // passive comparison here would either be redundant or fight it.
      return;
    }

    final activeStep = _ctx.state.internalActiveStep;
    if (activeStep == null) return;

    final overlay = _overlayKey.currentState;
    if (overlay == null) return;

    final overlayBox = overlay.overlayBox;
    final activeElement = _ctx.state.internalActiveElement;
    final rect = activeElement != null
        ? (rectOfContext(activeElement, overlayBox) ??
              _ctx.state.activeStagePosition)
        : centeredDummyRect(overlayBox);
    if (rect == null || rect == _ctx.state.activeStagePosition) return;

    refreshActiveHighlight(_ctx, overlay);
  }

  void _handleOverlayTap() {
    final behavior = _ctx.config.overlayClickBehavior;
    switch (behavior) {
      case OverlayClickBehaviorClose():
        if (_ctx.config.allowClose) _destroyInternal(withHook: true);
      case OverlayClickBehaviorCustom(:final handler):
        final step = _ctx.state.internalActiveStep;
        final element = _ctx.state.internalActiveElement;
        if (step != null) {
          handler(element, step, _ctx.getHookOpts());
        }
      case OverlayClickBehaviorNextStep():
        final step = _ctx.state.activeStep;
        final element = _ctx.state.activeElement;
        if (step == null) return;
        final hook = resolveNextHook(_ctx, step);
        if (hook != null) {
          hook(element, step, _ctx.getHookOpts());
          return;
        }
        moveNext();
    }
  }

  /// The hole-tap handler behind `advanceOnClick` (design decision #4),
  /// ported from `handleActiveElementClick` in `overlay.ts`. The cutout's
  /// hit-testing (`overlay_widget.dart`) already guarantees this only fires
  /// for a tap-up that landed inside the hole *and* wasn't swallowed by
  /// `disableActiveInteraction` — this handler owns the remaining checks:
  /// no advancing mid-transition, and only when the effective
  /// `advanceOnClick` (step overrides config) is actually on.
  void _handleHoleTap() {
    if (_ctx.state.transitionToken != null) return;

    final activeStep = _ctx.state.internalActiveStep;
    if (activeStep == null) return;

    final advanceOnClick =
        activeStep.advanceOnClick ?? _ctx.config.advanceOnClick;
    if (!advanceOnClick) return;

    final activeElement = _ctx.state.internalActiveElement;
    final hook = resolveNextHook(_ctx, activeStep);

    // Deferred to the next frame so the highlighted element's own gesture
    // handlers (e.g. its `onTap`) get to run first — mirrors JS's
    // bubble-phase event handling, where `onDriverClick` never calls
    // `preventDefault`/`stopPropagation` for a hole tap, letting the
    // browser's own dispatch continue to the target afterwards.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (hook != null) {
        hook(activeElement, activeStep, _ctx.getHookOpts());
      } else {
        moveNext();
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// A pending `waitForElement` timeout, if any — the only piece of the
  /// wait that needs an explicit cancel handle. The post-frame poll
  /// [_waitForStepElement] schedules cancels itself implicitly by checking
  /// [_waitToken] each time it runs (`addPostFrameCallback` has no cancel
  /// handle the way `cancelAnimationFrame`/`clearInterval` do, mirroring
  /// `RefreshScheduler`'s generation-counter trick in `events.dart`), but a
  /// live `Timer` left uncancelled would fire on its own schedule
  /// regardless of that check ever running again — and in tests, a `Timer`
  /// still pending when the test ends is an error in its own right, not
  /// just a correctness bug.
  Timer? _waitTimeoutTimer;

  /// Bumped by every [_cancelPendingWait] call (and every
  /// [_waitForStepElement] call, which starts by cancelling any previous
  /// wait) — see [_waitTimeoutTimer]'s doc comment for why the poll needs
  /// this even though the timer alone doesn't.
  int _waitToken = 0;

  /// Cancels any in-flight `waitForElement` poll/timeout, mirroring
  /// `cancelElementWait` in `driver.ts`. Called at the top of every
  /// [_drive] (a fresh navigation supersedes whatever the driver used to be
  /// waiting on), from [setSteps], and from [_destroyInternal]'s teardown —
  /// the same set of call sites `cancelElementWait()` has in driver.ts.
  void _cancelPendingWait() {
    _waitToken++;
    _waitTimeoutTimer?.cancel();
    _waitTimeoutTimer = null;
  }

  /// Polls for [step]'s element to mount (post-frame, since there's no
  /// Flutter analogue of the DOM `MutationObserver` `waitForStepElement` in
  /// driver.ts uses) for up to [timeout], then re-enters [_drive] with
  /// `hasWaitedForElement: true` — either because the element resolved, or
  /// because the wait simply ran out (in which case `_drive`'s normal
  /// missing-element handling — the skip walk, or a centered dummy
  /// highlight — takes over). The overlay is left completely untouched
  /// while this runs: whatever was highlighted before this call (if
  /// anything) stays highlighted, since [_drive] returned before reaching
  /// any of the highlight/mount code.
  void _waitForStepElement(int stepIndex, DriveStep step, Duration timeout) {
    final token = ++_waitToken;

    void settle() {
      // Superseded by a newer `_drive`/`_cancelPendingWait` call since this
      // was scheduled — don't resurrect a navigation the driver has since
      // moved past (or been destroyed out from under).
      if (_waitToken != token) return;
      _waitTimeoutTimer?.cancel();
      _waitTimeoutTimer = null;
      _drive(stepIndex, hasWaitedForElement: true);
    }

    void poll(Duration elapsed) {
      if (_waitToken != token) return;
      if (resolveTargetContext(step.element) != null) {
        settle();
        return;
      }
      // Re-arms for the next frame without forcing one itself (no
      // `ensureVisualUpdate()`) — same "ride whatever frames the app
      // produces anyway" approach as `_armRectWatcher` below. In practice
      // this is never starved: mounting the awaited element is itself
      // normally the result of a `setState`/rebuild, which is a frame.
      SchedulerBinding.instance.addPostFrameCallback(poll);
    }

    SchedulerBinding.instance.addPostFrameCallback(poll);
    _waitTimeoutTimer = Timer(timeout, settle);
  }

  void _handleEscape() {
    if (!_ctx.config.allowClose) return;
    _destroyInternal(withHook: true);
  }

  void _handleArrowRight() {
    if (_ctx.state.transitionToken != null) return;

    final activeIndex = _ctx.state.activeIndex;
    final activeStep = _ctx.state.internalActiveStep;
    if (activeIndex == null || activeStep == null) return;

    final hook = resolveNextHook(_ctx, activeStep);
    if (hook != null) {
      hook(_ctx.state.internalActiveElement, activeStep, _ctx.getHookOpts());
      return;
    }
    moveNext();
  }

  void _handleArrowLeft() {
    if (_ctx.state.transitionToken != null) return;

    final activeIndex = _ctx.state.activeIndex;
    final activeStep = _ctx.state.internalActiveStep;
    if (activeIndex == null || activeStep == null) return;

    final steps = _ctx.config.steps ?? const <DriveStep>[];
    final previousIndex = activeIndex - 1;
    if (previousIndex < 0 || previousIndex >= steps.length) {
      // No-op on the first step — a keyboard-only guard (design decision
      // #10); `movePrevious()` itself has no such guard, see its doc
      // comment.
      return;
    }

    final hook = resolvePrevHook(_ctx, activeStep);
    if (hook != null) {
      hook(_ctx.state.internalActiveElement, activeStep, _ctx.getHookOpts());
      return;
    }
    movePrevious();
  }

  @override
  void refresh() => _refreshScheduler?.requestRefresh();

  @override
  bool isActive() => _entry != null;

  @override
  void moveNext() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    final nextIndex = findReachableIndex(
      steps,
      activeIndex + 1,
      1,
      _shouldSkip,
    );
    if (nextIndex != null) {
      drive(nextIndex);
    } else {
      _destroyInternal(withHook: true);
    }
  }

  @override
  void movePrevious() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    final previousIndex = findReachableIndex(
      steps,
      activeIndex - 1,
      -1,
      _shouldSkip,
    );
    if (previousIndex != null) {
      drive(previousIndex);
    } else {
      _destroyInternal(withHook: true);
    }
  }

  @override
  void moveTo(int index) {
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    if (index >= 0 && index < steps.length) {
      drive(index);
    } else {
      _destroyInternal(withHook: true);
    }
  }

  @override
  bool hasNextStep() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return false;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    return findReachableIndex(steps, activeIndex + 1, 1, _shouldSkip) != null;
  }

  @override
  bool hasPreviousStep() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return false;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    return findReachableIndex(steps, activeIndex - 1, -1, _shouldSkip) != null;
  }

  @override
  bool isFirstStep() => _ctx.state.activeIndex != null && !hasPreviousStep();

  @override
  bool isLastStep() => _ctx.state.activeIndex != null && !hasNextStep();

  @override
  DriveStep? getActiveStep() => _ctx.state.activeStep;

  @override
  BuildContext? getActiveElement() => _ctx.state.activeElement;

  @override
  DriveStep? getPreviousStep() => _ctx.state.previousStep;

  @override
  BuildContext? getPreviousElement() => _ctx.state.previousElement;

  @override
  DriveStep? getNextStep() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return null;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    final nextIndex = findReachableIndex(
      steps,
      activeIndex + 1,
      1,
      _shouldSkip,
    );
    return nextIndex != null ? steps[nextIndex] : null;
  }

  @override
  int? getActiveIndex() => _ctx.state.activeIndex;

  @override
  DriverState getState() => _ctx.state;

  @override
  DriverConfig getConfig() => _ctx.config;

  @override
  void setConfig(DriverConfig config) => _ctx.setConfig(config);

  @override
  void setSteps(List<DriveStep> steps) {
    _cancelPendingWait();
    _ctx.state.reset();
    _ctx.setConfig(_ctx.config.copyWith(steps: steps));
  }

  @override
  void destroy() => _destroyInternal(withHook: false);

  /// The shared teardown implementation behind [destroy] and every
  /// internal, user-initiated close path (Esc, the popover's `x`, an
  /// overlay-click close, `moveNext`/`movePrevious`/`moveTo`/`drive` past
  /// either end). [withHook] mirrors `destroy(withOnDestroyStartedHook)` in
  /// `driver.ts`: when `true` and `config.onDestroyStarted` is set, the hook
  /// runs *instead of* tearing down — it has to call `driver.destroy()`
  /// itself (which always passes `withHook: false`) to actually close,
  /// which is what makes a confirm-on-exit dialog possible. Teardown order
  /// mirrors `driver.ts`'s `destroy()` exactly: cancel wait → detach
  /// listeners → remove the overlay entry → snapshot state → reset state →
  /// `onDeselected` then `onDestroyed` (against the snapshot) → restore
  /// whatever had focus before the most recent `drive()` call.
  void _destroyInternal({required bool withHook}) {
    if (_entry == null) return;

    // The *settled* element/step (`__activeElement`/`__activeStep` in
    // context.ts), not the unsettled `activeElement`/`activeStep` — a
    // destroy mid-transition should still describe whatever was actually on
    // screen, not a target the animation never reached.
    final activeElement = _ctx.state.internalActiveElement;
    final activeStep = _ctx.state.internalActiveStep;

    final onDestroyStarted = _ctx.config.onDestroyStarted;
    if (withHook && onDestroyStarted != null && activeStep != null) {
      onDestroyStarted(activeElement, activeStep, _ctx.getHookOpts());
      return;
    }

    final onDeselected = activeStep?.onDeselected ?? _ctx.config.onDeselected;
    final onDestroyed = _ctx.config.onDestroyed;

    _cancelPendingWait();

    if (_metricsObserver != null) {
      WidgetsBinding.instance.removeObserver(_metricsObserver!);
      _metricsObserver = null;
    }
    _refreshScheduler?.dispose();
    _refreshScheduler = null;

    _entry!.remove();
    _entry = null;

    final stateSnapshot = _ctx.state.copy();
    final focusToRestore = _ctx.state.focusToRestore;

    _ctx.state.reset();
    _ctx.resetEmitter();

    if (activeStep != null) {
      onDeselected?.call(
        activeElement,
        activeStep,
        _ctx.getHookOpts(stateOverride: stateSnapshot),
      );
      onDestroyed?.call(
        activeElement,
        activeStep,
        _ctx.getHookOpts(stateOverride: stateSnapshot),
      );
    }

    if (focusToRestore != null && focusToRestore.canRequestFocus) {
      focusToRestore.requestFocus();
    }
  }
}
