/// Orchestrates moving the highlight from one element to another, ported
/// from `highlight.ts`. This is the layer between `driver.dart` (which
/// decides *what* to highlight) and `overlay_widget.dart` (which knows how
/// to animate the stage rect and paint it) — it resolves elements to rects,
/// fires the lifecycle hooks, and drives the overlay's ticker.
///
/// Popover rendering (`renderStepPopover`/`repositionStepPopover` in the JS
/// source) is M2 scope and is skipped entirely here.
library;

import 'package:flutter/widgets.dart';

import 'context.dart';
import 'overlay_widget.dart';
import 'step.dart';
import 'utils.dart';

/// The rect driver.js's `mountDummyElement` stands in for an element-less
/// step: a zero-size point at the viewport center (`top: 50%; left: 50%;
/// width: 0; height: 0`, un-transformed — so its origin, not its center,
/// sits at the midpoint). Expressed in [overlayBox]'s local space, per
/// design decision #1.
Rect centeredDummyRect(RenderBox overlayBox) {
  final center = overlayBox.size.center(Offset.zero);
  return Rect.fromLTWH(center.dx, center.dy, 0, 0);
}

/// Moves the highlight from whatever was previously active to [toStep],
/// firing the `onDeselected`/`onHighlightStarted`/`onHighlighted` hooks and
/// driving [overlay]'s stage-chase ticker. Ported from `transferHighlight`
/// in `highlight.ts`, minus the popover render calls (M2) and the DOM
/// class-list/aria bookkeeping (which has no Flutter equivalent — the
/// `disableActiveInteraction` behavior it partly implements is instead
/// handled directly by `RenderOverlayCutout`'s hit-testing).
void transferHighlight(
  DriverContext ctx,
  DriveStep toStep,
  DriverOverlayState overlay,
) {
  final overlayBox = overlay.overlayBox;

  final toContext = resolveTargetContext(toStep.element);
  Rect resolveToRect() => toContext != null
      ? (rectOfContext(toContext, overlayBox) ?? centeredDummyRect(overlayBox))
      : centeredDummyRect(overlayBox);

  final fromStep = ctx.state.internalActiveStep;
  final fromElement = ctx.state.internalActiveElement;
  final fromRect = ctx.state.activeStagePosition ?? resolveToRect();

  // Mirrors `isFirstHighlight = !fromElement || fromElement === toElement`
  // in highlight.ts: skip the deselect hook when there's nothing to
  // deselect yet, or when re-highlighting the same element.
  final isFirstHighlight = fromElement == null || fromElement == toContext;

  final highlightStartedHook =
      toStep.onHighlightStarted ?? ctx.config.onHighlightStarted;
  final highlightedHook = toStep.onHighlighted ?? ctx.config.onHighlighted;
  final deselectedHook = fromStep?.onDeselected ?? ctx.config.onDeselected;

  final hookOpts = ctx.getHookOpts();

  if (!isFirstHighlight && deselectedHook != null && fromStep != null) {
    deselectedHook(fromElement, fromStep, hookOpts);
  }
  if (highlightStartedHook != null) {
    highlightStartedHook(toContext, toStep, hookOpts);
  }

  ctx.state.previousStep = fromStep;
  ctx.state.previousElement = fromElement;
  ctx.state.activeStep = toStep;
  ctx.state.activeElement = toContext;

  final disableActiveInteraction =
      toStep.disableActiveInteraction ?? ctx.config.disableActiveInteraction;
  overlay.updateDisableActiveInteraction(disableActiveInteraction);

  // A fresh token per call: `transitionStage`'s ticker (or its immediate
  // snap, if not animating) closes over it and checks it before writing
  // state, so a superseded call (another `highlight()` before this one's
  // animation finished) can't clobber state a newer call already owns —
  // mirrors highlight.ts's `transitionCallback !== animate` re-entrancy
  // guard.
  final token = Object();
  ctx.state.transitionToken = token;

  // Re-reads the element's rect fresh every call — this is what lets the
  // ticker "chase" an element that's still scrolling into view (design
  // decision #3): each tick calls this again rather than reusing a value
  // captured once at the start of the transition.
  Rect resolveLiveTarget() => resolveToRect();

  if (toContext != null) {
    bringInView(toContext, smoothScroll: ctx.config.smoothScroll);
  }

  overlay.transitionStage(
    from: fromRect,
    resolveTarget: resolveLiveTarget,
    duration: ctx.config.duration,
    animate: ctx.config.animate,
    onSettled: () {
      if (ctx.state.transitionToken != token) return;
      ctx.state.activeStagePosition = resolveLiveTarget();
      ctx.state.internalPreviousStep = fromStep;
      ctx.state.internalPreviousElement = fromElement;
      ctx.state.internalActiveStep = toStep;
      ctx.state.internalActiveElement = toContext;
      ctx.state.transitionToken = null;
      if (highlightedHook != null) {
        highlightedHook(toContext, toStep, ctx.getHookOpts());
      }
    },
  );
}

/// Re-syncs the stage to the active element's *current* rect without
/// animating, for resize/scroll-driven refreshes (`RefreshScheduler` in
/// `events.dart`) rather than a highlight transition. Ported from
/// `refreshActiveHighlight` in `highlight.ts`.
///
/// A no-op while a highlight transition is in flight: the ticker started by
/// [transferHighlight] already re-reads the live target rect every tick
/// (design decision #3), so there's nothing for a snap-refresh to do until
/// it settles.
void refreshActiveHighlight(DriverContext ctx, DriverOverlayState overlay) {
  if (ctx.state.transitionToken != null) return;

  final activeStep = ctx.state.internalActiveStep;
  if (activeStep == null) return;

  final overlayBox = overlay.overlayBox;
  final activeElement = ctx.state.internalActiveElement;
  final rect = activeElement != null
      ? (rectOfContext(activeElement, overlayBox) ??
            ctx.state.activeStagePosition)
      : centeredDummyRect(overlayBox);
  if (rect == null) return;

  ctx.state.activeStagePosition = rect;
  overlay.snapTo(rect);
}
