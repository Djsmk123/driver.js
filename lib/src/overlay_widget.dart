/// The mounted overlay: a full-screen dim with a rounded-rect cutout around
/// the highlighted element, animated between targets. Ported from
/// `overlay.ts` (the SVG cutout + `transitionStage`/`trackActiveElement`)
/// and `click.ts` (the capture-first click handling), adapted to Flutter's
/// render-object/hit-testing model per design decisions #2-#4 in the plan.
///
/// The popover widget itself is out of scope for M1 (see `highlight.dart`);
/// this file only owns the dim + cutout + its animation.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'stage.dart';
import 'theme.dart';
import 'utils.dart';

/// Leaf render object painting the full-screen dim with a rounded-rect hole
/// around [stageRect], and splitting hit-testing between the dim (opaque)
/// and the hole (translucent) regions — design decisions #2 and #4.
///
/// This is a leaf (no child) deliberately: the "hole is translucent"
/// behavior isn't implemented by punching a compositing hole, it's
/// implemented by [hitTest] returning `false` for points inside the hole,
/// which tells Flutter's hit-testing to keep probing whatever is *behind*
/// this render object in the tree — i.e. the app content the root overlay
/// entry (design decision #1) sits on top of.
class RenderOverlayCutout extends RenderBox {
  // Initializing formals bound directly to the private fields (Dart still
  // exposes these as public named parameters — `stageRect:` etc — at every
  // call site; only the *field* is private). The hand-written `set`
  // methods below stay the only place that does cache invalidation /
  // repaint on every *later* update; the constructor doesn't need that on
  // first set.
  RenderOverlayCutout({
    required this._stageRect,
    required this._overlayColor,
    required this._overlayOpacity,
    required this._stagePadding,
    required this._stageRadius,
    required this._disableActiveInteraction,
    required this._onOverlayTap,
  });

  Rect _stageRect;
  set stageRect(Rect value) {
    if (_stageRect == value) return;
    _stageRect = value;
    _invalidatePathCache();
    markNeedsPaint();
  }

  Color _overlayColor;
  set overlayColor(Color value) {
    if (_overlayColor == value) return;
    _overlayColor = value;
    markNeedsPaint();
  }

  double _overlayOpacity;
  set overlayOpacity(double value) {
    if (_overlayOpacity == value) return;
    _overlayOpacity = value;
    markNeedsPaint();
  }

  double _stagePadding;
  set stagePadding(double value) {
    if (_stagePadding == value) return;
    _stagePadding = value;
    _invalidatePathCache();
    markNeedsPaint();
  }

  double _stageRadius;
  set stageRadius(double value) {
    if (_stageRadius == value) return;
    _stageRadius = value;
    _invalidatePathCache();
    markNeedsPaint();
  }

  /// When `true`, the hole swallows taps instead of letting them fall
  /// through to the highlighted element — design decision #4's
  /// "disableActiveInteraction" hole variant.
  bool _disableActiveInteraction;
  set disableActiveInteraction(bool value) => _disableActiveInteraction = value;

  VoidCallback _onOverlayTap;
  set onOverlayTap(VoidCallback value) => _onOverlayTap = value;

  Path? _cachedPath;
  Size? _cachedPathSize;

  void _invalidatePathCache() => _cachedPath = null;

  Path _path() {
    if (_cachedPath == null || _cachedPathSize != size) {
      _cachedPath = buildStagePath(
        screenSize: size,
        target: _stageRect,
        padding: _stagePadding,
        radius: _stageRadius,
      );
      _cachedPathSize = size;
    }
    return _cachedPath!;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performResize() {
    size = constraints.biggest;
    _invalidatePathCache();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final path = offset == Offset.zero ? _path() : _path().shift(offset);
    final paint = Paint()
      ..color = _overlayColor.withValues(alpha: _overlayOpacity);
    context.canvas.drawPath(path, paint);
  }

  // Hit-testing is handled entirely here rather than via `hitTestSelf`,
  // because the hole case needs to return `false` (keep probing behind
  // this render object) rather than just "not handled, but still opaque".
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & size).contains(position)) {
      return false;
    }

    final inDimRegion = _path().contains(position);
    if (inDimRegion || _disableActiveInteraction) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }

    // Inside the hole, interaction allowed: let the hit test continue to
    // whatever the root overlay entry is stacked on top of.
    return false;
  }

  Offset? _downPosition;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _downPosition = event.position;
    } else if (event is PointerUpEvent) {
      final down = _downPosition;
      _downPosition = null;
      if (down != null && (event.position - down).distance <= kTouchSlop) {
        _onOverlayTap();
      }
    } else if (event is PointerCancelEvent) {
      _downPosition = null;
    }
  }
}

class _CutoutWidget extends LeafRenderObjectWidget {
  const _CutoutWidget({
    required this.stageRect,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.stagePadding,
    required this.stageRadius,
    required this.disableActiveInteraction,
    required this.onOverlayTap,
  });

  final Rect stageRect;
  final Color overlayColor;
  final double overlayOpacity;
  final double stagePadding;
  final double stageRadius;
  final bool disableActiveInteraction;
  final VoidCallback onOverlayTap;

  @override
  RenderOverlayCutout createRenderObject(BuildContext context) {
    return RenderOverlayCutout(
      stageRect: stageRect,
      overlayColor: overlayColor,
      overlayOpacity: overlayOpacity,
      stagePadding: stagePadding,
      stageRadius: stageRadius,
      disableActiveInteraction: disableActiveInteraction,
      onOverlayTap: onOverlayTap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOverlayCutout renderObject,
  ) {
    renderObject
      ..stageRect = stageRect
      ..overlayColor = overlayColor
      ..overlayOpacity = overlayOpacity
      ..stagePadding = stagePadding
      ..stageRadius = stageRadius
      ..disableActiveInteraction = disableActiveInteraction
      ..onOverlayTap = onOverlayTap;
  }
}

/// The widget mounted into the root `OverlayEntry` (design decision #1).
/// Owns the stage-chase [Ticker] and the one-time dim fade-in; everything
/// else (resolving elements, orchestrating hooks) lives in `highlight.dart`
/// and calls back into this widget's [DriverOverlayState] via a
/// `GlobalKey<DriverOverlayState>`, the same way `overlay.ts`'s functions
/// take a `ctx` and reach into DOM state it doesn't own itself.
class DriverOverlay extends StatefulWidget {
  const DriverOverlay({
    super.key,
    required this.initialStageRect,
    required this.theme,
    required this.disableActiveInteraction,
    required this.fadeInDuration,
    required this.animateFadeIn,
    required this.onOverlayTap,
  });

  final Rect initialStageRect;
  final DriverTheme theme;
  final bool disableActiveInteraction;

  /// Length of the one-time dim fade-in played on mount (design decision
  /// #3). This is `DriverConfig.duration` at construction time; unlike the
  /// stage-chase animation, the fade-in isn't re-triggered by later
  /// highlight calls.
  final Duration fadeInDuration;

  /// Whether the fade-in plays at all — `DriverConfig.animate` at
  /// construction time. When `false` the dim is fully opaque from the
  /// first frame.
  final bool animateFadeIn;

  final VoidCallback onOverlayTap;

  @override
  State<DriverOverlay> createState() => DriverOverlayState();
}

class DriverOverlayState extends State<DriverOverlay>
    with SingleTickerProviderStateMixin<DriverOverlay> {
  late Rect _stageRect = widget.initialStageRect;
  late DriverTheme _theme = widget.theme;
  late bool _disableActiveInteraction = widget.disableActiveInteraction;
  VoidCallback _onOverlayTap = () {};

  late final AnimationController _dimFade = AnimationController(
    vsync: this,
    duration: widget.fadeInDuration,
  );

  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _onOverlayTap = widget.onOverlayTap;
    if (widget.animateFadeIn && widget.fadeInDuration > Duration.zero) {
      _dimFade.forward();
    } else {
      _dimFade.value = 1;
    }
  }

  /// The overlay's own render box, in whose local coordinate space every
  /// stage rect this widget is given is expressed (design decision #1).
  RenderBox get overlayBox => context.findRenderObject()! as RenderBox;

  /// Swaps the visual theme (colors/padding/radius) without touching the
  /// stage rect or any in-flight animation.
  void updateTheme(DriverTheme theme) => setState(() => _theme = theme);

  /// Updates whether the hole swallows taps (design decision #4).
  void updateDisableActiveInteraction(bool value) =>
      setState(() => _disableActiveInteraction = value);

  /// Replaces the dim-tap handler (rebuilding a step can change what a tap
  /// should do, e.g. a different `overlayClickBehavior.custom` handler).
  void updateOverlayTapHandler(VoidCallback handler) => _onOverlayTap = handler;

  /// Immediately snaps the stage to [rect], canceling any in-flight
  /// animation. Used by `refreshActiveHighlight` (a resize/scroll-driven
  /// refresh, not a highlight transition — see `highlight.dart`), which
  /// mirrors `trackActiveElement` in `overlay.ts`.
  void snapTo(Rect rect) {
    _stopTicker();
    setState(() => _stageRect = rect);
  }

  /// The exact port of `transitionStage`'s animation loop (design decision
  /// #3): each tick re-reads the *live* target rect via [resolveTarget] —
  /// so a target still settling into view after a scroll keeps getting
  /// chased — and eases every rect component from the stage's *current*
  /// value (not the original [from]) using [easeInOutQuadJs]. Any
  /// previously running transition is canceled first, so a retarget
  /// mid-flight restarts smoothly from wherever the stage currently is.
  ///
  /// When [animate] is `false` or [duration] is zero, this snaps straight
  /// to `resolveTarget()` and calls [onSettled] synchronously, matching
  /// `highlight.ts`'s non-animated branch (which calls `trackActiveElement`
  /// immediately instead of scheduling frames).
  void transitionStage({
    required Rect from,
    required Rect Function() resolveTarget,
    required Duration duration,
    required bool animate,
    required VoidCallback onSettled,
  }) {
    _stopTicker();

    if (!animate || duration <= Duration.zero) {
      setState(() => _stageRect = resolveTarget());
      onSettled();
      return;
    }

    setState(() => _stageRect = from);

    final durationMs = duration.inMicroseconds / 1000;
    _ticker = createTicker((elapsed) {
      final elapsedMs = elapsed.inMicroseconds / 1000;
      if (elapsedMs >= durationMs) {
        _stopTicker();
        setState(() => _stageRect = resolveTarget());
        onSettled();
        return;
      }

      final to = resolveTarget();
      final current = _stageRect;
      final x = easeInOutQuadJs(
        elapsedMs,
        current.left,
        to.left - current.left,
        durationMs,
      );
      final y = easeInOutQuadJs(
        elapsedMs,
        current.top,
        to.top - current.top,
        durationMs,
      );
      final w = easeInOutQuadJs(
        elapsedMs,
        current.width,
        to.width - current.width,
        durationMs,
      );
      final h = easeInOutQuadJs(
        elapsedMs,
        current.height,
        to.height - current.height,
        durationMs,
      );
      setState(() => _stageRect = Rect.fromLTWH(x, y, w, h));
    });
    _ticker!.start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    _dimFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _dimFade,
      child: _CutoutWidget(
        stageRect: _stageRect,
        overlayColor: _theme.overlayColor,
        overlayOpacity: _theme.overlayOpacity,
        stagePadding: _theme.stagePadding,
        stageRadius: _theme.stageRadius,
        disableActiveInteraction: _disableActiveInteraction,
        onOverlayTap: () => _onOverlayTap(),
      ),
    );
  }
}
