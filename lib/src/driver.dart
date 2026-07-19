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
/// `waitForElement`, `skipMissingElement` walking, `advanceOnClick` and
/// `disableActiveInteraction`-driven advancement are explicitly out of
/// scope — M4. `drive()` here assumes every step's element resolves
/// synchronously and nothing is ever skipped (`neverSkipStep` in
/// `step.dart`), but every navigation method already goes through
/// `findReachableIndex` so M4 can drop in a real skip predicate without a
/// rewrite.
library;

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
  void drive([int stepIndex = 0]) {
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
    final mountContext = _resolveMountContext(currentStep);
    if (mountContext == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'driverjs: could not resolve a BuildContext to mount the overlay.',
        ),
        ErrorDescription(
          'Pass `context:` in DriverConfig, or make sure step $stepIndex\'s '
          '`element` resolves to a mounted widget before calling drive().',
        ),
      ]);
    }
    _ensureMounted(mountContext);

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
          neverSkipStep,
        );
        if (nextIndex != null) {
          drive(nextIndex);
        } else {
          _destroyInternal(withHook: true);
        }
      },
      onPrevClick: (element, step, opts) => drive(stepIndex - 1),
      onCloseClick: (element, step, opts) => _destroyInternal(withHook: true),
    );

    final resolvedStep = resolveTourStep(_ctx, stepIndex, defaults);

    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _performHighlight(resolvedStep),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

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
  }

  void _handleRefresh() {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
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

  // M4 will populate this with real `waitForElement` cancellation
  // (`cancelElementWait` in `driver.ts`); the call site exists in `drive()`
  // now so that milestone doesn't need to touch `drive()` itself.
  void _cancelPendingWait() {}

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
      neverSkipStep,
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
      neverSkipStep,
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
    return findReachableIndex(steps, activeIndex + 1, 1, neverSkipStep) != null;
  }

  @override
  bool hasPreviousStep() {
    final activeIndex = _ctx.state.activeIndex;
    if (activeIndex == null) return false;
    final steps = _ctx.config.steps ?? const <DriveStep>[];
    return findReachableIndex(steps, activeIndex - 1, -1, neverSkipStep) !=
        null;
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
      neverSkipStep,
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
