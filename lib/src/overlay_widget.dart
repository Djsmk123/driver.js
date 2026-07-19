/// The mounted overlay: a full-screen dim with a rounded-rect cutout around
/// the highlighted element, animated between targets, plus (M2) the
/// popover positioned against it. Ported from `overlay.ts` (the SVG cutout
/// + `transitionStage`/`trackActiveElement`) and `click.ts` (the
/// capture-first click handling), adapted to Flutter's render-object/hit-
/// testing model per design decisions #2-#4 in the plan.
///
/// This widget deliberately stays ignorant of *how* the popover's content
/// or placement inputs are decided (that's `highlight.dart`'s job, mirroring
/// `renderStepPopover`/`repositionStepPopover` in `step.ts`) — it only owns
/// the dim + cutout + popover positioner and their animations, the same
/// division M1 drew around the cutout alone.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'popover_widget.dart';
import 'position.dart';
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
    required this._onHoleTap,
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

  /// Fired on tap-up inside the hole when it's *not* swallowing taps (i.e.
  /// `disableActiveInteraction` is off) — design decision #4's
  /// `advanceOnClick` hook. `driver.dart`'s handler owns the actual
  /// "effective `advanceOnClick`" + mid-transition checks; this render
  /// object only reports that a qualifying tap happened.
  VoidCallback _onHoleTap;
  set onHoleTap(VoidCallback value) => _onHoleTap = value;

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
  // because the hole (normal, interactive) case needs to both (a) let the
  // hit test continue behind this render object — so the highlighted app
  // element's own gesture handlers still fire, design decision #4 — and
  // (b) still have `handleEvent` called on *this* object for the same
  // pointer, so `advanceOnClick` can observe the tap. Those two things are
  // controlled independently in Flutter: `result.add` alone decides who
  // gets `handleEvent`, while this method's return value only tells the
  // ancestor `Stack` whether to keep probing earlier (lower-z) children —
  // the same "add unconditionally, return false to stay translucent"
  // technique `RenderProxyBoxWithHitTestBehavior` uses for
  // `HitTestBehavior.translucent`.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & size).contains(position)) {
      return false;
    }

    final inDimRegion = _path().contains(position);
    final consumesHit = inDimRegion || _disableActiveInteraction;

    result.add(BoxHitTestEntry(this, position));
    return consumesHit;
  }

  Offset? _downPosition;
  bool _downInDimRegion = false;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _downPosition = event.position;
      _downInDimRegion = _path().contains(event.localPosition);
    } else if (event is PointerUpEvent) {
      final down = _downPosition;
      final downInDimRegion = _downInDimRegion;
      _downPosition = null;
      if (down == null || (event.position - down).distance > kTouchSlop) {
        return;
      }

      if (downInDimRegion) {
        _onOverlayTap();
      } else if (!_disableActiveInteraction) {
        // Hole tap, interaction allowed — `advanceOnClick` candidate. A
        // `disableActiveInteraction` hole tap swallows silently: no
        // `_onOverlayTap`, no `_onHoleTap`, and (per `hitTest` above)
        // `consumesHit` already blocked the target's own gesture handlers
        // from ever seeing it.
        _onHoleTap();
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
    required this.onHoleTap,
  });

  final Rect stageRect;
  final Color overlayColor;
  final double overlayOpacity;
  final double stagePadding;
  final double stageRadius;
  final bool disableActiveInteraction;
  final VoidCallback onOverlayTap;
  final VoidCallback onHoleTap;

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
      onHoleTap: onHoleTap,
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
      ..onOverlayTap = onOverlayTap
      ..onHoleTap = onHoleTap;
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
    required this.onHoleTap,
    required this.allowKeyboardControl,
    required this.onEscape,
    required this.onArrowRight,
    required this.onArrowLeft,
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

  /// Fired on a qualifying tap-up inside the hole (design decision #4's
  /// `advanceOnClick` candidate) — see [RenderOverlayCutout]'s field of the
  /// same name for exactly which taps reach it.
  final VoidCallback onHoleTap;

  /// Gates all keyboard handling below — `DriverConfig.allowKeyboardControl`
  /// at mount time (design decision #10). `false` makes every key a no-op.
  final bool allowKeyboardControl;

  /// Escape key-up. The `allowClose`/`onDestroyStarted`-interception gating
  /// lives in `driver.dart`'s handler, not here — this widget only forwards
  /// the raw key event.
  final VoidCallback onEscape;

  /// ArrowRight key-up (next/done). Mid-transition and reachability
  /// guarding live in `driver.dart`'s handler.
  final VoidCallback onArrowRight;

  /// ArrowLeft key-up (previous, no-op on the first step). Mid-transition
  /// and reachability guarding live in `driver.dart`'s handler.
  final VoidCallback onArrowLeft;

  @override
  State<DriverOverlay> createState() => DriverOverlayState();
}

class DriverOverlayState extends State<DriverOverlay>
    with TickerProviderStateMixin<DriverOverlay> {
  late Rect _stageRect = widget.initialStageRect;
  late DriverTheme _theme = widget.theme;
  late bool _disableActiveInteraction = widget.disableActiveInteraction;
  VoidCallback _onOverlayTap = () {};
  VoidCallback _onHoleTap = () {};

  late final AnimationController _dimFade = AnimationController(
    vsync: this,
    duration: widget.fadeInDuration,
  );

  // Popover state (M2). Unlike `_dimFade` (played once on mount), this
  // fade is replayed on *every* popover render — "the popover fades in on
  // every step render" (design decision #3) — since a fresh popover
  // replaces the previous one's content outright rather than cross-fading.
  Widget? _popoverContent;
  Rect _popoverElement = Rect.zero;
  bool _popoverCentered = false;
  Side _popoverSide = Side.bottom;
  PopoverAlignment _popoverAlign = PopoverAlignment.start;
  double _popoverOffset = 20;
  double _popoverPadding = 10;
  Color _popoverArrowColor = const Color(0xFFFFFFFF);

  late final AnimationController _popoverFade = AnimationController(
    vsync: this,
    duration: widget.fadeInDuration,
  );

  Ticker? _ticker;

  /// Owns the popover's Tab-traversal cycle (design decision #10): a
  /// dedicated [FocusScopeNode], rather than the ambient one, so
  /// [FocusTraversalGroup]'s Tab/Shift+Tab cycling stays confined to the
  /// popover's own focusable controls (buttons, close button) and never
  /// wanders onto the highlighted app element's focusables — a documented
  /// limitation, not a bug; see the plan's design decision #10.
  final FocusScopeNode _popoverFocusScope = FocusScopeNode(
    debugLabel: 'driverjs-popover',
  );

  @override
  void initState() {
    super.initState();
    _onOverlayTap = widget.onOverlayTap;
    _onHoleTap = widget.onHoleTap;
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

  /// Shows (or replaces) the popover, mirroring `renderPopover` in
  /// `popover.ts` minus everything `highlight.dart` already resolved
  /// before calling this — [content] is the fully-built widget (default
  /// content or a `DriverPopoverBuilder`'s result), and [element]/
  /// [centered]/[side]/[align]/[offset]/[padding] are exactly
  /// [resolvePopoverPlacement]'s parameters, computed fresh by the caller
  /// (immediately, or at the halfway point — see [transitionStage]'s
  /// `onHalfway`).
  ///
  /// Replays [_popoverFade] from 0 every call — the popover's fade-in is
  /// per-render, not per-mount, unlike [_dimFade].
  void showPopover({
    required Widget content,
    required Rect element,
    required bool centered,
    required Side side,
    required PopoverAlignment align,
    required double offset,
    required double padding,
    required Color arrowColor,
  }) {
    setState(() {
      _popoverContent = content;
      _popoverElement = element;
      _popoverCentered = centered;
      _popoverSide = side;
      _popoverAlign = align;
      _popoverOffset = offset;
      _popoverPadding = padding;
      _popoverArrowColor = arrowColor;
    });
    if (widget.animateFadeIn && widget.fadeInDuration > Duration.zero) {
      _popoverFade
        ..value = 0
        ..forward();
    } else {
      _popoverFade.value = 1;
    }

    // "On popover render, focus the first focusable control automatically"
    // (design decision #10). Deferred to a post-frame callback: the
    // popover's own focusable descendants (buttons, close button) haven't
    // built into `_popoverFocusScope` yet on this same call — `setState`
    // above only *schedules* that rebuild.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _popoverFocusScope.nextFocus();
    });
  }

  /// Removes the popover immediately (no fade-out — matches
  /// `hidePopover`'s `display: none` in `popover.ts`, called at the start
  /// of every `transferHighlight` before the new one is (maybe delayed)
  /// rendered).
  void hidePopover() {
    if (_popoverContent == null) return;
    setState(() => _popoverContent = null);
  }

  /// Re-anchors an already-visible popover to [element]'s current rect
  /// without touching its content or replaying the fade — used by
  /// `refreshActiveHighlight` (mirrors `repositionStepPopover` there). A
  /// no-op while no popover is showing.
  void updatePopoverAnchor(Rect element) {
    if (_popoverContent == null) return;
    setState(() => _popoverElement = element);
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
  ///
  /// [onHalfway], if given, fires exactly once, the first tick where
  /// elapsed time reaches half of [duration] — this is the "wait for the
  /// animation to finish" branch's halfway point from `transferHighlight`
  /// in `highlight.ts` (`isHalfwayThrough = timeRemaining <= duration /
  /// 2`), which `highlight.dart` uses to delay a non-first popover's
  /// render until the stage transition is half done. Never called from the
  /// non-animated snap branch above — a caller that wants an immediate
  /// popover render on that path calls it itself before invoking this
  /// method, exactly as `highlight.dart` does.
  void transitionStage({
    required Rect from,
    required Rect Function() resolveTarget,
    required Duration duration,
    required bool animate,
    required VoidCallback onSettled,
    VoidCallback? onHalfway,
  }) {
    _stopTicker();

    if (!animate || duration <= Duration.zero) {
      setState(() => _stageRect = resolveTarget());
      onSettled();
      return;
    }

    setState(() => _stageRect = from);

    final durationMs = duration.inMicroseconds / 1000;
    var halfwayFired = false;
    _ticker = createTicker((elapsed) {
      final elapsedMs = elapsed.inMicroseconds / 1000;
      if (!halfwayFired && onHalfway != null && elapsedMs >= durationMs / 2) {
        halfwayFired = true;
        onHalfway();
      }
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
    _popoverFade.dispose();
    _popoverFocusScope.dispose();
    super.dispose();
  }

  /// Key-up routing (design decision #10), ported from `onKeyup` in
  /// `events.ts`. `allowKeyboardControl` gates everything; beyond that this
  /// widget only identifies *which* key fired and forwards to the matching
  /// callback — `driver.dart`'s handlers own every semantic guard
  /// (mid-transition no-op, `allowClose`, first/last-step reachability).
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.allowKeyboardControl) return KeyEventResult.ignored;
    if (event is! KeyUpEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onEscape();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.onArrowRight();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        widget.onArrowLeft();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final popoverContent = _popoverContent;
    return FocusScope(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          FadeTransition(
            opacity: _dimFade,
            child: _CutoutWidget(
              stageRect: _stageRect,
              overlayColor: _theme.overlayColor,
              overlayOpacity: _theme.overlayOpacity,
              stagePadding: _theme.stagePadding,
              stageRadius: _theme.stageRadius,
              disableActiveInteraction: _disableActiveInteraction,
              onOverlayTap: () => _onOverlayTap(),
              onHoleTap: () => _onHoleTap(),
            ),
          ),
          if (popoverContent != null)
            FadeTransition(
              opacity: _popoverFade,
              // A dedicated `FocusTraversalGroup` + `FocusScope` confines
              // Tab/Shift+Tab cycling to just the popover's own focusable
              // controls (design decision #10) — the surrounding
              // `FocusScope` above still owns Escape/arrow-key routing, but
              // traversal order inside it stops at this boundary.
              child: FocusTraversalGroup(
                child: FocusScope(
                  node: _popoverFocusScope,
                  child: PopoverPositioner(
                    element: _popoverElement,
                    side: _popoverSide,
                    align: _popoverAlign,
                    offset: _popoverOffset,
                    padding: _popoverPadding,
                    centered: _popoverCentered,
                    arrowColor: _popoverArrowColor,
                    arrowSize: _theme.popoverArrowSize,
                    child: popoverContent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
