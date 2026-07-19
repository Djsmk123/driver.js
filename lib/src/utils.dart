/// Small geometry/element-resolution helpers shared by the overlay,
/// highlight and (later) scroll subsystems. Ported from driver.js's
/// `utils.ts`, adapted to Flutter's element model (no DOM, no CSS
/// selectors).
library;

import 'package:flutter/widgets.dart';

/// Resolves the various forms `DriveStep.element` (and later
/// `DriverHint.element`) can take into a live [BuildContext], mirroring
/// `resolveElement` in `utils.ts` (which resolves a CSS selector string, a
/// DOM `Element`, or a thunk returning one).
///
/// Flutter has no CSS selectors, so the accepted shapes are Flutter-native
/// instead:
///  - a [GlobalKey], whose `currentContext` is read live — a key that
///    hasn't mounted yet (or has since unmounted) naturally resolves to
///    `null`, so callers get the same "no element" handling driver.js gets
///    for a selector that matches nothing;
///  - a [BuildContext] directly, returned only while [BuildContext.mounted];
///  - a zero-arg function returning any of the above (or `null`), resolved
///    at call time — the Dart equivalent of the JS thunk form
///    `() => Element`.
///
/// Returns `null` for a `null` [element] (an intentional element-less,
/// "centered" step) or when the above resolution fails.
BuildContext? resolveTargetContext(Object? element) {
  if (element == null) {
    return null;
  }
  if (element is GlobalKey) {
    return element.currentContext;
  }
  if (element is BuildContext) {
    return element.mounted ? element : null;
  }
  if (element is Object? Function()) {
    return resolveTargetContext(element());
  }
  throw ArgumentError(
    'Unsupported element type: ${element.runtimeType}. Expected a '
    'GlobalKey, a BuildContext, or a zero-arg function returning one of '
    'those (or null).',
  );
}

/// The bounding rect of [context]'s render box, expressed in [ancestor]'s
/// local coordinate space. This is the Flutter analogue of
/// `Element.getBoundingClientRect()`: every geometry function in this
/// package (see [position.dart] and [stage.dart]) works in "overlay-local"
/// coordinates (design decision #1 in the plan), and [ancestor] is always
/// the root overlay's render box in practice.
///
/// Returns `null` if [context]'s render object doesn't exist yet, isn't a
/// [RenderBox], is detached, or hasn't been laid out — all states a
/// `GlobalKey.currentContext` can transiently be in, which callers should
/// treat the same way a vanished DOM element would be (keep the last known
/// rect; see `refreshActiveHighlight` in `highlight.dart`).
Rect? rectOfContext(BuildContext context, RenderObject ancestor) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: ancestor);
  return topLeft & renderObject.size;
}

/// Scrolls [context] into view of its nearest [Scrollable], mirroring
/// `bringInView` in `utils.ts` — with one deliberate deviation (design
/// decision #11): JS's `isElementInView` checks the element's rect against
/// `window.innerWidth/Height` (the whole browser viewport); we check it
/// against [overlayBox]'s bounds instead, since design decision #1 already
/// makes the root overlay's own size the Flutter analogue of the viewport
/// everywhere else in this package. Skips scrolling entirely when the
/// target is already fully visible there — not merely because
/// `Scrollable.ensureVisible` would end up computing a zero-delta scroll in
/// that case anyway, but because skipping the call outright avoids handing
/// it a nonzero [duration] that would otherwise animate a no-op.
///
/// [smoothScroll] toggles [duration] vs. an instant `Duration.zero` jump,
/// and the "taller than the viewport" block-alignment quirk picks `0.0`
/// (top-aligned) over `0.5` (centered) the same way JS's
/// `isTallerThanViewport ? "start" : "center"` does. Unlike JS's
/// `hasScrollableParent` smooth-scroll suppression (worked around a
/// specific browser rendering bug), that check has no Flutter analogue and
/// isn't ported — `Scrollable.ensureVisible` doesn't share the bug it
/// existed for.
///
/// A `null` [Scrollable.maybeOf] result (the target has no scrollable
/// ancestor at all) or a not-yet-laid-out [context] both no-op, same as a
/// missing element does in JS.
///
/// This runs concurrently with the stage-chase animation
/// (`transitionStage` in `overlay_widget.dart`) — `transferHighlight` in
/// `highlight.dart` deliberately doesn't `await` this, so scrolling and the
/// stage/popover animation proceed in parallel, each tick of the ticker
/// re-reading the live (mid-scroll) target rect per design decision #3.
///
/// `DriverConfig.allowScroll: false` has no effect on this function itself
/// — see that field's doc comment and design decision #11's documented
/// parity gap: the dim region is already opaque (`RenderOverlayCutout`'s
/// hit-testing) and so already absorbs scroll gestures made outside the
/// hole, which covers most of what `allowScroll: false` is for; a wheel
/// scroll landing *inside* the hole (over the highlighted element itself)
/// isn't blocked, unlike JS's `document.body` `overflow: hidden` toggle,
/// which has no Flutter-idiomatic equivalent given the hole must otherwise
/// stay interactive.
Future<void> bringInView(
  BuildContext context,
  RenderBox overlayBox, {
  bool smoothScroll = false,
  Duration duration = const Duration(milliseconds: 400),
}) async {
  if (!context.mounted) return;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return;
  }

  final scrollableState = Scrollable.maybeOf(context);
  if (scrollableState == null) return;

  final elementRect = rectOfContext(context, overlayBox);
  if (elementRect == null) return;

  final overlayBounds = Offset.zero & overlayBox.size;
  final fullyVisible =
      elementRect.top >= overlayBounds.top &&
      elementRect.left >= overlayBounds.left &&
      elementRect.bottom <= overlayBounds.bottom &&
      elementRect.right <= overlayBounds.right;
  if (fullyVisible) return;

  final isTallerThanViewport =
      renderObject.size.height > scrollableState.position.viewportDimension;

  await Scrollable.ensureVisible(
    context,
    alignment: isTallerThanViewport ? 0.0 : 0.5,
    duration: smoothScroll ? duration : Duration.zero,
    curve: Curves.easeInOut,
  );
}

/// Exact port of `easeInOutQuad` from `utils.ts` — a classic 4-arg
/// "initial value / amount of change" quadratic ease, NOT Flutter's
/// [Curves.easeInOutQuad] (which is a *cubic* approximation and produces
/// different values). The stage-chase ticker in `overlay_widget.dart` calls
/// this directly so the highlight animation matches driver.js frame for
/// frame; [EaseInOutQuadCurve] below wraps it as a [Curve] for callers that
/// want a normalized 0..1 curve instead (e.g. a future `AnimationController`
/// use in the popover).
///
/// - [elapsed]: milliseconds since the transition started.
/// - [initialValue]: the value at `elapsed == 0`.
/// - [amountOfChange]: `endValue - initialValue`.
/// - [duration]: total transition length in milliseconds.
double easeInOutQuadJs(
  double elapsed,
  double initialValue,
  double amountOfChange,
  double duration,
) {
  var t = elapsed / (duration / 2);
  if (t < 1) {
    return (amountOfChange / 2) * t * t + initialValue;
  }
  t -= 1;
  return (-amountOfChange / 2) * (t * (t - 2) - 1) + initialValue;
}

/// [Curve] wrapper around [easeInOutQuadJs], normalized to the `[0, 1]` →
/// `[0, 1]` domain a [Curve] is expected to satisfy: this is exactly
/// `easeInOutQuadJs(t, 0, 1, 1)`.
class EaseInOutQuadCurve extends Curve {
  const EaseInOutQuadCurve();

  @override
  double transform(double t) => easeInOutQuadJs(t, 0, 1, 1);
}
