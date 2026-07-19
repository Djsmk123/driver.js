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
/// `bringInView` in `utils.ts` (skip-if-already-visible, smooth-scroll
/// toggle, "taller than the viewport" block alignment, and the
/// scrollable-parent smooth-scroll suppression it applies).
///
/// Full scrolling support is M4 scope (see design decision #11 in the
/// plan); this stub exists now so `driver.dart`/`highlight.dart` have a
/// stable call site to wire up once that milestone lands, and so this
/// function's signature — not its behavior — is settled during M1.
Future<void> bringInView(
  BuildContext context, {
  bool smoothScroll = false,
}) async {
  // TODO(M4): port isElementInView / hasScrollableParent / block alignment
  // and call Scrollable.ensureVisible.
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
