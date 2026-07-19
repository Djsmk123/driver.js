/// The popover *widget*: a render object that positions a child box against
/// an anchor rect and paints the CSS-triangle arrow (the rendering half of
/// `popover.ts`+`popover.css` — the pure math it calls into lives in
/// `position.dart`, already ported in M1), plus the default popover content
/// widget matching `popover.css` exactly. Design decision #8 in the plan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'popover.dart';
import 'position.dart';
import 'theme.dart';

/// Lays out its single child with the width band `popover.css` hard-codes
/// (`min-width: 250px; max-width: 300px`, clamped further so an overlay
/// narrower than `2 * arrowSize + 300` never asks the arrow to sit outside
/// the popover), then places it in one pass via [resolvePopoverPlacement]
/// and paints the 10x10 CSS-border-triangle arrow in [arrowColor].
///
/// This is a leaf-ish [RenderShiftedBox]: unlike [RenderOverlayCutout] (a
/// true leaf with no child), a popover *has* one child — its content — but
/// still owns painting the arrow itself, since the arrow isn't part of
/// that child's box; it's an extra triangle glued to one of its edges.
class RenderPopoverPositioner extends RenderShiftedBox {
  // Initializing formals bound directly to the private fields, the same
  // pattern `RenderOverlayCutout` uses (see overlay_widget.dart): Dart
  // still exposes these as public named parameters (`element:`, `side:`,
  // …) at every call site; only the *field* is private.
  RenderPopoverPositioner({
    RenderBox? child,
    required this._element,
    required this._side,
    required this._align,
    required this._offset,
    required this._padding,
    required this._centered,
    required this._arrowColor,
    this._arrowSize = kArrowSize,
  }) : super(child);

  Rect _element;
  set element(Rect value) {
    if (_element == value) return;
    _element = value;
    markNeedsLayout();
  }

  Side _side;
  set side(Side value) {
    if (_side == value) return;
    _side = value;
    markNeedsLayout();
  }

  PopoverAlignment _align;
  set align(PopoverAlignment value) {
    if (_align == value) return;
    _align = value;
    markNeedsLayout();
  }

  double _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsLayout();
  }

  double _padding;
  set padding(double value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _centered;
  set centered(bool value) {
    if (_centered == value) return;
    _centered = value;
    markNeedsLayout();
  }

  Color _arrowColor;
  set arrowColor(Color value) {
    if (_arrowColor == value) return;
    _arrowColor = value;
    markNeedsPaint();
  }

  double _arrowSize;
  set arrowSize(double value) {
    if (_arrowSize == value) return;
    _arrowSize = value;
    markNeedsLayout();
  }

  /// The most recently resolved placement, exposed so widget tests can
  /// assert the *widget* actually landed where `resolvePopoverPlacement`'s
  /// pure math (already unit-tested in `position_test.dart`) says it
  /// should, without having to re-derive overlay geometry themselves.
  PopoverPlacement? get placement => _placement;
  PopoverPlacement? _placement;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      _placement = null;
      return;
    }

    // `min(300, overlayWidth - 2*arrowSize)` per design decision #8 — on a
    // very narrow overlay this can dip below `minWidth`/even below zero;
    // clamp so BoxConstraints never sees `minWidth > maxWidth` or a
    // negative width.
    final maxWidth = math.max(
      0.0,
      math.min(300.0, size.width - 2 * _arrowSize),
    );
    final minWidth = math.min(250.0, maxWidth);
    child.layout(
      BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      parentUsesSize: true,
    );

    final placement = resolvePopoverPlacement(
      element: _element,
      popoverSize: child.size,
      overlaySize: size,
      side: _side,
      align: _align,
      offset: _offset,
      padding: _padding,
      arrowSize: _arrowSize,
      centered: _centered,
    );
    _placement = placement;
    (child.parentData! as BoxParentData).offset = placement.offset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    final child = this.child;
    final placement = _placement;
    if (child == null || placement == null) return;

    final arrowSide = placement.arrowSide;
    final arrowOffset = placement.arrowOffset;
    if (arrowSide == null || arrowOffset == null) {
      // Centered or pinned-bottom placement: no arrow (design decision #7).
      return;
    }

    final childOffset = (child.parentData! as BoxParentData).offset;
    final popoverOrigin = offset + childOffset;
    _paintArrow(
      context.canvas,
      popoverOrigin,
      child.size,
      arrowSide,
      arrowOffset,
    );
  }

  /// Paints the 10x10 (well, [_arrowSize] square) CSS-border-triangle arrow
  /// described in `position.dart`'s [resolveArrowSide] doc comment: the
  /// triangle's flat base sits flush against whichever popover edge
  /// [arrowSide] names, with the apex centered on the perpendicular edge —
  /// exactly what a CSS box with one visible 5px border (and the other
  /// three transparent) renders as.
  void _paintArrow(
    Canvas canvas,
    Offset popoverOrigin,
    Size popoverSize,
    Side arrowSide,
    double arrowOffset,
  ) {
    final Rect box;
    switch (arrowSide) {
      case Side.bottom:
        // Sits on the popover's TOP edge, apex pointing up (`bottom: 100%`
        // in popover.css — the arrow's own bottom edge touches the
        // popover's top edge).
        box = Rect.fromLTWH(
          popoverOrigin.dx + arrowOffset,
          popoverOrigin.dy - _arrowSize,
          _arrowSize,
          _arrowSize,
        );
      case Side.top:
        // Sits on the popover's BOTTOM edge, apex pointing down (`top:
        // 100%`).
        box = Rect.fromLTWH(
          popoverOrigin.dx + arrowOffset,
          popoverOrigin.dy + popoverSize.height,
          _arrowSize,
          _arrowSize,
        );
      case Side.right:
        // Sits on the popover's LEFT edge, apex pointing left (`right:
        // 100%`).
        box = Rect.fromLTWH(
          popoverOrigin.dx - _arrowSize,
          popoverOrigin.dy + arrowOffset,
          _arrowSize,
          _arrowSize,
        );
      case Side.left:
        // Sits on the popover's RIGHT edge, apex pointing right (`left:
        // 100%`).
        box = Rect.fromLTWH(
          popoverOrigin.dx + popoverSize.width,
          popoverOrigin.dy + arrowOffset,
          _arrowSize,
          _arrowSize,
        );
    }

    final path = Path();
    switch (arrowSide) {
      case Side.bottom: // apex up
        path
          ..moveTo(box.left, box.bottom)
          ..lineTo(box.right, box.bottom)
          ..lineTo(box.left + box.width / 2, box.top)
          ..close();
      case Side.top: // apex down
        path
          ..moveTo(box.left, box.top)
          ..lineTo(box.right, box.top)
          ..lineTo(box.left + box.width / 2, box.bottom)
          ..close();
      case Side.right: // apex left
        path
          ..moveTo(box.right, box.top)
          ..lineTo(box.right, box.bottom)
          ..lineTo(box.left, box.top + box.height / 2)
          ..close();
      case Side.left: // apex right
        path
          ..moveTo(box.left, box.top)
          ..lineTo(box.left, box.bottom)
          ..lineTo(box.right, box.top + box.height / 2)
          ..close();
    }

    canvas.drawPath(path, Paint()..color = _arrowColor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Rect>('element', _element))
      ..add(EnumProperty<Side>('side', _side))
      ..add(EnumProperty<PopoverAlignment>('align', _align))
      ..add(DoubleProperty('offset', _offset))
      ..add(DoubleProperty('padding', _padding))
      ..add(DiagnosticsProperty<bool>('centered', _centered))
      ..add(DiagnosticsProperty<PopoverPlacement?>('placement', _placement));
  }
}

/// Widget wrapper around [RenderPopoverPositioner]. Mounted directly (like
/// `overlay_widget.dart`'s `_CutoutWidget`) as a non-`Positioned` child of
/// the overlay's `Stack`, so it receives the same full-overlay loose
/// constraints the cutout does and its `sizedByParent` layout fills them.
class PopoverPositioner extends SingleChildRenderObjectWidget {
  const PopoverPositioner({
    super.key,
    required this.element,
    required this.side,
    required this.align,
    required this.offset,
    required this.padding,
    required this.centered,
    required this.arrowColor,
    this.arrowSize = kArrowSize,
    super.child,
  });

  final Rect element;
  final Side side;
  final PopoverAlignment align;
  final double offset;
  final double padding;
  final bool centered;
  final Color arrowColor;
  final double arrowSize;

  @override
  RenderPopoverPositioner createRenderObject(BuildContext context) {
    return RenderPopoverPositioner(
      element: element,
      side: side,
      align: align,
      offset: offset,
      padding: padding,
      centered: centered,
      arrowColor: arrowColor,
      arrowSize: arrowSize,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPopoverPositioner renderObject,
  ) {
    renderObject
      ..element = element
      ..side = side
      ..align = align
      ..offset = offset
      ..padding = padding
      ..centered = centered
      ..arrowColor = arrowColor
      ..arrowSize = arrowSize;
  }
}

/// The default popover content widget — everything `popover.css` styles
/// except the arrow (painted by [RenderPopoverPositioner], not this
/// widget, since it sits outside this box). Replaced wholesale by a
/// `DriverPopoverBuilder` when one is configured; when it isn't, this is
/// what `highlight.dart` wraps in [PopoverPositioner].
class DriverPopoverContent extends StatelessWidget {
  const DriverPopoverContent({
    super.key,
    required this.data,
    required this.theme,
  });

  final DriverPopoverData data;
  final DriverTheme theme;

  bool get _showClose => data.showButtons.contains(DriverButton.close);

  @override
  Widget build(BuildContext context) {
    final showFooter =
        data.showButtons.contains(DriverButton.next) ||
        data.showButtons.contains(DriverButton.previous) ||
        data.showProgress;

    // The close button is positioned `top: 0; right: 0` relative to
    // popover.css's *padding box* — i.e. flush with the popover's outer
    // edge, ignoring its own 15px content padding, so it visually
    // overlaps the top-right corner of the title/description area. A
    // Stack around the whole decorated box (not just its padded content)
    // is what reproduces that; wrapping it *inside* the padded Column
    // would inset it by the padding instead.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(minWidth: theme.popoverMinWidth),
              padding: theme.popoverPadding,
              decoration: BoxDecoration(
                color: theme.popoverBackgroundColor,
                borderRadius: BorderRadius.circular(theme.popoverBorderRadius),
                boxShadow: theme.popoverShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.titleWidget != null)
                    data.titleWidget!
                  else if (data.title != null)
                    Text(
                      data.title!,
                      style: TextStyle(
                        fontSize: theme.popoverTitleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: theme.popoverTextColor,
                      ),
                    ),
                  if (data.descriptionWidget != null)
                    Padding(
                      padding: EdgeInsets.only(
                        top: (data.titleWidget != null || data.title != null)
                            ? 5
                            : 0,
                      ),
                      child: data.descriptionWidget,
                    )
                  else if (data.description != null)
                    Padding(
                      padding: EdgeInsets.only(
                        top: (data.titleWidget != null || data.title != null)
                            ? 5
                            : 0,
                      ),
                      child: Text(
                        data.description!,
                        style: TextStyle(
                          fontSize: theme.popoverDescriptionFontSize,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: theme.popoverTextColor,
                        ),
                      ),
                    ),
                  if (showFooter) _Footer(data: data, theme: theme),
                ],
              ),
            ),
          ),
          if (_showClose)
            Positioned(
              top: 0,
              right: 0,
              child: _CloseButton(
                theme: theme,
                onPressed: data.onCloseClick,
                disabled: data.disableButtons.contains(DriverButton.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.data, required this.theme});

  final DriverPopoverData data;
  final DriverTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (data.showProgress)
            Text(
              data.progressText ?? '',
              style: TextStyle(
                fontSize: theme.popoverProgressFontSize,
                fontWeight: FontWeight.w400,
                color: theme.popoverProgressTextColor,
              ),
            )
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.showButtons.contains(DriverButton.previous))
                _FooterButton(
                  text: data.prevBtnText,
                  theme: theme,
                  onPressed: data.onPrevClick,
                  disabled: data.disableButtons.contains(DriverButton.previous),
                ),
              if (data.showButtons.contains(DriverButton.previous) &&
                  data.showButtons.contains(DriverButton.next))
                SizedBox(width: theme.popoverButtonSpacing),
              if (data.showButtons.contains(DriverButton.next))
                _FooterButton(
                  text: data.nextBtnText,
                  theme: theme,
                  onPressed: data.onNextClick,
                  disabled: data.disableButtons.contains(DriverButton.next),
                ),
              for (final extra in data.extraFooterChildren) ...[
                SizedBox(width: theme.popoverButtonSpacing),
                extra,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// `.driver-popover-footer-btn`: 12px text, 3x7 padding, 1px `#ccc` border,
/// 3px radius, `#f7f7f7` on hover, 0.5 opacity + no interaction when
/// [disabled].
class _FooterButton extends StatefulWidget {
  const _FooterButton({
    required this.text,
    required this.theme,
    required this.onPressed,
    required this.disabled,
  });

  final String text;
  final DriverTheme theme;
  final VoidCallback? onPressed;
  final bool disabled;

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final button = MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onPressed,
        child: Container(
          padding: theme.popoverButtonPadding,
          decoration: BoxDecoration(
            color: _hovered && !widget.disabled
                ? theme.popoverButtonHoverBackgroundColor
                : theme.popoverButtonBackgroundColor,
            border: Border.all(color: theme.popoverButtonBorderColor),
            borderRadius: BorderRadius.circular(
              theme.popoverButtonBorderRadius,
            ),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: theme.popoverButtonFontSize,
              height: 1.3,
              color: theme.popoverButtonTextColor,
            ),
          ),
        ),
      ),
    );

    // `Focus` (design decision #10): the popover's Tab focus trap
    // (`overlay_widget.dart`'s `FocusTraversalGroup`) has nothing to cycle
    // through unless its buttons are themselves focusable — a bare
    // `GestureDetector` carries no focus node of its own. Disabled buttons
    // opt out of both receiving focus and appearing in traversal order, on
    // top of already swallowing taps via `IgnorePointer`.
    return Focus(
      canRequestFocus: !widget.disabled,
      skipTraversal: widget.disabled,
      onKeyEvent: (node, event) {
        if (widget.disabled || widget.onPressed == null) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.disabled
          ? IgnorePointer(child: Opacity(opacity: 0.5, child: button))
          : button,
    );
  }
}

/// `.driver-popover-close-btn`: 32x28, `#d2d2d2` → `#2d2d2d` on hover, "×"
/// glyph, absolute top-right.
class _CloseButton extends StatefulWidget {
  const _CloseButton({
    required this.theme,
    required this.onPressed,
    required this.disabled,
  });

  final DriverTheme theme;
  final VoidCallback? onPressed;
  final bool disabled;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final button = MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onPressed,
        child: SizedBox(
          width: theme.popoverCloseButtonSize.width,
          height: theme.popoverCloseButtonSize.height,
          child: Semantics(
            button: true,
            label: 'Close',
            child: Center(
              child: Text(
                '×',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _hovered && !widget.disabled
                      ? theme.popoverCloseButtonHoverColor
                      : theme.popoverCloseButtonColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // See `_FooterButtonState.build`'s comment on why this needs a `Focus`
    // wrapper at all (design decision #10's Tab focus trap).
    return Focus(
      canRequestFocus: !widget.disabled,
      skipTraversal: widget.disabled,
      onKeyEvent: (node, event) {
        if (widget.disabled || widget.onPressed == null) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.disabled
          ? IgnorePointer(child: Opacity(opacity: 0.5, child: button))
          : button,
    );
  }
}
