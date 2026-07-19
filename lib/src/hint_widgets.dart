/// The pulsing beacon widget and its supporting config classes
/// (`HintBeacon`/`HintBeaconStyle`/`HintPopover`), plus the pure anchor-point
/// and popover-position math `hints.dart`'s controller calls into. Ported
/// from `hints.ts`'s `positionBeacon`/`popoverPosition` and `hints.css`'s
/// `.driver-hint`/`.driver-hint-dot`/`.driver-hint-pulse` rules. Design
/// decision #12 in the plan.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'hints.dart';
import 'position.dart';

/// The hint popover's arrow is bigger than the tour's (`position.dart`'s
/// `kArrowSize`, 10) — `hints.css`'s `.driver-hint-popover
/// .driver-popover-arrow { border-width: 7px }` (a 14x14 box). Placement
/// math measures this directly rather than the rendered arrow, since the
/// beacon-anchored shift below (`resolveHintPopoverPosition`) has to be
/// computed before the popover widget exists to measure.
const double kHintArrowSize = 14;

/// `hints.ts`'s `OVERLAY_PADDING`/`OVERLAY_RADIUS`: the cutout hugging the
/// active hint's element in overlay mode, mirroring the tour's own stage
/// defaults but fixed rather than themeable — hints intentionally have a
/// single, simple visual language independent of `DriverTheme`.
const double kHintOverlayPadding = 10;
const double kHintOverlayRadius = 5;

/// Per-hint (or `HintsConfig`-wide default) beacon configuration. Mirrors
/// `HintBeacon` in `hints.ts`, minus `className` (no CSS classes in
/// Flutter — [HintBeaconStyle] plus a `DriverPopoverBuilder`-style override
/// would be the equivalent hook, not needed for M5's scope).
class HintBeacon {
  const HintBeacon({
    this.side,
    this.align,
    this.animate,
    this.offsetX = 0,
    this.offsetY = 0,
    this.style,
  });

  /// Which edge of the element the beacon sits on. `null` resolves to
  /// [Side.top], matching `positionBeacon`'s `side = "top"` default.
  final Side? side;

  /// Where along that edge. `null` resolves to [PopoverAlignment.end],
  /// matching `positionBeacon`'s `align = "end"` default.
  final PopoverAlignment? align;

  /// `null` (the default) means "animate unless the platform asks
  /// otherwise" — resolved against `MediaQuery.disableAnimations` by
  /// [HintBeaconWidget] itself, since that's a `BuildContext`-only signal.
  /// An explicit `false` always wins; an explicit `true` still yields to
  /// `MediaQuery.disableAnimations`.
  final bool? animate;

  /// Pixel nudge from the computed anchor point. Positive moves
  /// right/down.
  final double offsetX;
  final double offsetY;

  /// `null` resolves to `HintBeaconStyle()`'s defaults.
  final HintBeaconStyle? style;
}

/// Visual constants for the beacon, lifted from `hints.css`'s custom
/// properties (`--driver-hint-size`, `--driver-hint-color`,
/// `--driver-hint-animation-duration`).
class HintBeaconStyle {
  const HintBeaconStyle({
    this.size = 24,
    this.color = const Color(0xFF818CF8),
    this.pulseDuration = const Duration(seconds: 2),
  });

  /// `.driver-hint`'s `width`/`height`.
  final double size;

  /// `.driver-hint-dot`/`.driver-hint-pulse`'s `background-color`.
  final Color color;

  /// `@keyframes driver-hint-pulse`'s `animation-duration`.
  final Duration pulseDuration;
}

/// Per-hint popover configuration. Mirrors `HintPopover` in `hints.ts`,
/// with the `String`/`Widget` twin pattern `popover.dart`'s
/// `DriverPopover` already established (design decision #8) rather than
/// `popoverClass`, and [onPopoverRender] handed a [DriverPopoverData] — the
/// same mutable model the tour's popover uses — instead of a
/// hints-specific DOM type.
class HintPopover {
  const HintPopover({
    this.title,
    this.description,
    this.titleWidget,
    this.descriptionWidget,
    this.side,
    this.align,
    this.showButton = true,
    this.buttonText,
    this.onButtonClick,
    this.onPopoverRender,
  });

  final String? title;
  final String? description;

  /// Wins over [title] when both are set.
  final Widget? titleWidget;

  /// Wins over [description] when both are set.
  final Widget? descriptionWidget;

  /// `null` resolves to [Side.bottom], matching `popoverPosition`'s
  /// `side || "bottom"` default.
  final Side? side;

  /// `null` resolves to [PopoverAlignment.start], matching
  /// `popoverPosition`'s `align || "start"` default.
  final PopoverAlignment? align;

  /// Hides the single dismiss button, leaving a popover only closeable
  /// programmatically via `Hints.close()`/`dismiss()`.
  final bool showButton;

  /// Falls back to `HintsConfig.buttonText`, then `'Got it'` — see
  /// `hints.dart`'s popover-render code for the exact chain.
  final String? buttonText;

  /// Runs *instead of* the default dismiss-on-click when set — same
  /// "replaces, doesn't chain" contract driver.js's `onButtonClick`
  /// documents. The caller must call `hints.dismiss(id)` itself if they
  /// still want the hint to go away.
  final HintHook? onButtonClick;

  /// Called with the resolved [DriverPopoverData] before layout, mirroring
  /// `popover.dart`'s [PopoverRenderHook] but scoped to a hint (an
  /// [HintHookOpts] instead of [DriverHookOpts], since there's no tour
  /// `Driver`/`DriveStep` involved).
  final HintPopoverRenderHook? onPopoverRender;
}

/// One of the twelve side×align anchor points on [element]'s box, plus the
/// [offsetX]/[offsetY] nudge — the point [HintBeaconWidget] centers itself
/// on. Exact port of `positionBeacon` in `hints.ts` (minus the
/// `getBoundingClientRect()` read, which the caller already did to produce
/// [element]).
Offset resolveBeaconAnchorPoint({
  required Rect element,
  required Side side,
  required PopoverAlignment align,
  required double offsetX,
  required double offsetY,
}) {
  final double top;
  final double left;

  if (side == Side.top || side == Side.bottom) {
    top = side == Side.top ? element.top : element.bottom;
    left = switch (align) {
      PopoverAlignment.start => element.left,
      PopoverAlignment.center => element.left + element.width / 2,
      PopoverAlignment.end => element.right,
    };
  } else {
    left = side == Side.left ? element.left : element.right;
    top = switch (align) {
      PopoverAlignment.start => element.top,
      PopoverAlignment.center => element.top + element.height / 2,
      PopoverAlignment.end => element.bottom,
    };
  }

  return Offset(left + offsetX, top + offsetY);
}

/// The resolved inputs `resolvePopoverPlacement` needs to place a hint's
/// popover — everything [HintPopoverPosition]'s two call sites in
/// `hints.dart` (normal vs. overlay mode) differ on, bundled so the
/// controller only has to branch once. Mirrors `popoverPosition` in
/// `hints.ts`.
class HintPopoverPosition {
  const HintPopoverPosition({
    required this.anchor,
    required this.side,
    required this.align,
    required this.offset,
    required this.padding,
  });

  /// In normal mode, a near-zero [Rect] centered on the beacon's anchor
  /// point (`resolveBeaconAnchorPoint`) — [resolvePopoverPlacement] treats
  /// it exactly like a real element rect, so nothing about the placement
  /// math itself needs to know it's synthetic. In overlay mode, the hint's
  /// actual element rect.
  final Rect anchor;
  final Side side;
  final PopoverAlignment align;
  final double offset;
  final double padding;
}

/// Computes [HintPopoverPosition] for [popover] against a hint whose
/// element/beacon geometry the caller already resolved. Exact port of
/// `popoverPosition` in `hints.ts`, including the padding formula's
/// comment: "shift the popover by the difference between the arrow tip and
/// the beacon's half-size ... so ... the arrow points at the beacon's
/// center instead of beside it" — with the plan's defaults (arrow size 14,
/// beacon size 24) that's `(15 + 7) - 12 = 10`.
HintPopoverPosition resolveHintPopoverPosition({
  required HintPopover popover,
  required Rect elementRect,
  required Offset beaconPoint,
  required double beaconSize,
  required double popoverOffset,
  required bool overlay,
}) {
  final side = popover.side ?? Side.bottom;
  final align = popover.align ?? PopoverAlignment.start;

  if (overlay) {
    // Overlay mode reads like a tour step: the popover clears the cutout
    // ring and lines up with its edge, anchored to the real element.
    return HintPopoverPosition(
      anchor: elementRect,
      side: side,
      align: align,
      offset: kHintOverlayPadding + popoverOffset,
      padding: kHintOverlayPadding,
    );
  }

  final arrowTip = kArrowCornerInset + kHintArrowSize / 2;
  return HintPopoverPosition(
    anchor: Rect.fromCenter(center: beaconPoint, width: 0, height: 0),
    side: side,
    align: align,
    // The popover hangs off the beacon; there's no stage to clear, so the
    // gap is exactly `HintsConfig.popoverOffset` with no stage padding
    // added.
    offset: popoverOffset,
    padding: arrowTip - beaconSize / 2,
  );
}

/// A pulsing beacon: a solid dot inset 25% into its box (`.driver-hint-dot`)
/// with an expanding, fading ring behind it (`.driver-hint-pulse` /
/// `@keyframes driver-hint-pulse`), tappable to toggle its popover.
///
/// The pulse scales `0.5` → `1.5` and fades opacity `0.6` → `0`, completing
/// both by 70% of [HintBeaconStyle.pulseDuration] and holding there for the
/// remaining 30% (matching the keyframe's `70% { ... } to { same as 70% }`
/// shape, rather than Flutter's default "ease across the whole 0..1 range"
/// repeating-animation feel) — eased with [Curves.easeOut] on the fade,
/// mirroring the CSS animation's `ease-out` timing function.
class HintBeaconWidget extends StatefulWidget {
  const HintBeaconWidget({
    super.key,
    required this.style,
    required this.animate,
    required this.onTap,
    this.focusNode,
  });

  final HintBeaconStyle style;

  /// The raw, unresolved `HintBeacon.animate` — `null` means "animate
  /// unless `MediaQuery.disableAnimations` says otherwise", resolved in
  /// [build] since that requires a [BuildContext].
  final bool? animate;

  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<HintBeaconWidget> createState() => HintBeaconWidgetState();
}

class HintBeaconWidgetState extends State<HintBeaconWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool? _resolvedAnimate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant HintBeaconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.style.pulseDuration != widget.style.pulseDuration) {
      _syncController();
    }
  }

  void _syncController() {
    final resolved =
        (widget.animate ?? true) && !MediaQuery.of(context).disableAnimations;
    if (resolved == _resolvedAnimate &&
        _controller?.duration == widget.style.pulseDuration) {
      return;
    }
    _resolvedAnimate = resolved;
    _controller?.dispose();
    _controller = null;
    if (resolved) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.style.pulseDuration,
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Exposed for widget tests: whether the pulse ring is actually
  /// animating right now, without having to reach into [_controller]
  /// directly.
  bool get isAnimating => _controller != null;

  @override
  Widget build(BuildContext context) {
    final size = widget.style.size;
    final controller = _controller;

    return Focus(
      focusNode: widget.focusNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          label: 'Show hint',
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (controller != null)
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      const holdAt = 0.7;
                      final progress = math.min(controller.value / holdAt, 1.0);
                      final scale = 0.5 + (1.5 - 0.5) * progress;
                      final opacity =
                          0.6 * (1 - Curves.easeOut.transform(progress));
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.style.color,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 0.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.style.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
