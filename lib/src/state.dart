/// Mutable per-driver state, mirroring `context.ts`'s `State` type.
library;

import 'package:flutter/widgets.dart';

import 'step.dart';

/// Runtime state for one `Driver` instance.
///
/// Unlike `DriverConfig` (replaced wholesale on `setConfig` — see
/// `context.dart`), `context.ts`'s state is a single long-lived object that
/// `getState`/`setState` mutate field by field. This is ported the same
/// way: plain mutable fields rather than an immutable value class, because
/// the JS flow-control logic this package mirrors (e.g. checking
/// `__transitionCallback`/`__activeElement` mid-call to no-op re-entrant
/// `transferHighlight` calls) depends on reading state another in-flight
/// call just wrote.
class DriverState {
  /// Set once the driver's overlay entry has been mounted.
  bool isInitialized = false;

  /// Index of the active tour step. `null` outside a tour (e.g. a bare
  /// `highlight()` call). M3 scope.
  int? activeIndex;

  /// The element passed to the most recent `highlight()`/`drive()` call,
  /// before any transition has settled — `activeElement` in context.ts.
  BuildContext? activeElement;

  /// The step config paired with [activeElement] on the most recent
  /// `highlight()`/`drive()` call — `activeStep` in context.ts. Like
  /// [activeElement], this is the pre-settle value; `refreshActiveHighlight`
  /// reads [internalActiveStep] instead once a transition is in flight.
  DriveStep? activeStep;

  /// The previously active element/step at the time of the most recent
  /// highlight call — `previousElement`/`previousStep` in context.ts. Not
  /// the same as "the step before this one" once tour skip-walks exist
  /// (M3); see `getPreviousStep` in the plan's public API sketch.
  BuildContext? previousElement;
  DriveStep? previousStep;

  /// Effective/settled element+step, considering in-flight transitions and
  /// (in M2) popover-render delays — `__activeElement`/`__activeStep`/
  /// `__previousElement`/`__previousStep` in context.ts. These lag
  /// [activeElement]/[activeStep] until a highlight's animation finishes;
  /// `refreshActiveHighlight` in `highlight.dart` reads these, not the
  /// unsettled ones, so a resize mid-transition doesn't fight the ticker.
  BuildContext? internalActiveElement;
  DriveStep? internalActiveStep;
  BuildContext? internalPreviousElement;
  DriveStep? internalPreviousStep;

  /// The live-eased stage rect, updated every animation tick and on every
  /// snap — `__activeStagePosition` in context.ts.
  Rect? activeStagePosition;

  /// Non-null while a highlight transition owns the stage ticker. Acts the
  /// same way `__transitionCallback` does in context.ts: a token (rather
  /// than a callback reference, since Dart's ticker lives on the overlay
  /// widget's state, not here) that a superseded transition can compare
  /// itself against to know to stop mutating state.
  Object? transitionToken;

  /// Whatever had focus right before `drive()` most recently highlighted a
  /// step — `__activeOnDestroyed` in context.ts (captured fresh on every
  /// `drive()` call, not just tour start, so it always reflects focus right
  /// before the *currently* active step, e.g. whichever popover button was
  /// clicked to navigate there). `destroy()` restores focus here once
  /// teardown finishes. `null` for a bare, tour-less `highlight()` — only
  /// `drive()` captures it, mirroring JS.
  FocusNode? focusToRestore;

  /// Clears every field back to its initial value, called on `destroy()`.
  void reset() {
    isInitialized = false;
    activeIndex = null;
    activeElement = null;
    activeStep = null;
    previousElement = null;
    previousStep = null;
    internalActiveElement = null;
    internalActiveStep = null;
    internalPreviousElement = null;
    internalPreviousStep = null;
    activeStagePosition = null;
    transitionToken = null;
    focusToRestore = null;
  }

  /// A shallow snapshot of every field, taken right before [reset] clears
  /// them — mirrors `const stateBeforeDestroy = ctx.getState()` in
  /// `driver.ts`'s `destroy()`, used to give `onDeselected`/`onDestroyed`
  /// hooks a [DriverState] that still reflects the tour that just ended,
  /// even though the live [DriverState] this instance itself has already
  /// been reset by the time those hooks run.
  DriverState copy() => DriverState()
    ..isInitialized = isInitialized
    ..activeIndex = activeIndex
    ..activeElement = activeElement
    ..activeStep = activeStep
    ..previousElement = previousElement
    ..previousStep = previousStep
    ..internalActiveElement = internalActiveElement
    ..internalActiveStep = internalActiveStep
    ..internalPreviousElement = internalPreviousElement
    ..internalPreviousStep = internalPreviousStep
    ..activeStagePosition = activeStagePosition
    ..transitionToken = transitionToken
    ..focusToRestore = focusToRestore;
}
