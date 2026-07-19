/// Pure positioning math for a popover box against an anchor rect, ported
/// from driver.js's `position.ts`. This module has no Flutter widget
/// dependency beyond `dart:ui` geometry types, so it can be unit tested
/// without pumping a widget tree.
///
/// The full popover *widget* (positioner render object, arrow paint) lands
/// in M2; this file only computes where things should go.
library;

import 'dart:math' as math;
import 'dart:ui';

/// The side of the anchor a popover (or hint) is placed on.
enum Side { top, right, bottom, left }

/// Cross-axis alignment of a popover relative to its anchor.
///
/// Named `PopoverAlignment` (not `Alignment`) to avoid clashing with
/// `package:flutter/painting.dart`'s `Alignment`.
enum PopoverAlignment { start, center, end }

/// The tour arrow is a CSS triangle built from 5px borders in driver.js, so
/// its bounding box is 10x10. This is the default `arrowSize` used by the
/// arrow-math functions below and by [resolvePopoverPlacement]; callers with
/// a differently-sized arrow (the hint popover uses 14) pass their own.
const double kArrowSize = 10;

/// Keep the arrow this far from the popover's corners so it never collides
/// with the rounded corners.
const double kArrowCornerInset = 15;

/// Finds the point the arrow should aim at along one axis, returned relative
/// to the popover's leading edge (`popoverStart`). All inputs share one axis
/// (both top/bottom or both left/right).
///
/// When the element fully spans the popover edge the arrow could point
/// anywhere along the popover and still land on the element, so there is
/// slack to spend: it's resolved with the configured alignment
/// (start/center/end), which makes the arrow echo the popover's own
/// alignment.
///
/// Otherwise this aims at the center of the region where the element and
/// popover overlap. This tracks the element rather than its geometric center
/// (which can sit far off-screen for an element much taller/wider than the
/// popover), and when the two don't overlap at all the clamped endpoints
/// collapse onto the nearest edge, pointing the arrow that way.
double calculateArrowTarget(
  double elementStart,
  double elementEnd,
  double popoverStart,
  double popoverEnd,
  PopoverAlignment alignment, {
  double arrowSize = kArrowSize,
}) {
  final popoverLength = popoverEnd - popoverStart;
  final fullySpansPopover =
      elementStart <= popoverStart && elementEnd >= popoverEnd;

  if (fullySpansPopover) {
    switch (alignment) {
      case PopoverAlignment.start:
        return kArrowCornerInset + arrowSize / 2;
      case PopoverAlignment.end:
        return popoverLength - kArrowCornerInset - arrowSize / 2;
      case PopoverAlignment.center:
        return popoverLength / 2;
    }
  }

  final overlapStart = math.min(
    math.max(elementStart, popoverStart),
    popoverEnd,
  );
  final overlapEnd = math.min(math.max(elementEnd, popoverStart), popoverEnd);

  return (overlapStart + overlapEnd) / 2 - popoverStart;
}

/// Turns the target point into the inline offset for the arrow box, clamped
/// so the whole arrow stays attached to the popover body and clear of its
/// rounded corners. [popoverLength] is the popover's size along the arrow's
/// edge.
double calculateArrowOffset(
  double targetCenter,
  double popoverLength, {
  double arrowSize = kArrowSize,
}) {
  const minOffset = kArrowCornerInset;
  final maxOffset = popoverLength - kArrowCornerInset - arrowSize;

  // The popover is too small to honor the corner insets; center the arrow.
  if (maxOffset < minOffset) {
    return math.max(0, (popoverLength - arrowSize) / 2);
  }

  final offset = targetCenter - arrowSize / 2;
  return math.min(math.max(offset, minOffset), maxOffset);
}

/// Decides which popover edge the arrow sits on. Normally this is the
/// rendered side, but when the element scrolls clear of the popover along
/// that side's axis (e.g. a left-placed popover whose element has scrolled
/// above it), the arrow moves to the perpendicular edge so it keeps pointing
/// at the element instead of sliding into a corner and pointing into empty
/// space.
///
/// Note the inverted naming inherited from driver.js: "bottom" sits on the
/// popover's top edge pointing up, "top" sits on the bottom edge pointing
/// down, "right" sits on the left edge pointing left, and "left" sits on the
/// right edge pointing right. That inversion is a rendering detail for
/// whichever widget paints the arrow (M2); this function only reports which
/// [Side] value to use.
Side resolveArrowSide(Side side, Rect element, Rect popover) {
  if (side == Side.left || side == Side.right) {
    final overlapsVertically =
        element.bottom > popover.top && element.top < popover.bottom;
    if (overlapsVertically) {
      return side;
    }

    return element.bottom <= popover.top ? Side.bottom : Side.top;
  }

  final overlapsHorizontally =
      element.right > popover.left && element.left < popover.right;
  if (overlapsHorizontally) {
    return side;
  }

  return element.right <= popover.left ? Side.right : Side.left;
}

/// The resolved placement of a popover: where to put its top-left corner
/// (in the same coordinate space as the [Rect]s passed to
/// [resolvePopoverPlacement], typically overlay-local), which side it ended
/// up rendered on, and where the arrow should point.
///
/// [renderedSide] and [arrowSide]/[arrowOffset] are `null` when the popover
/// is centered in the viewport (an anchor-less, modal-like popover) or
/// pinned to the bottom-center because no side had room — in both cases
/// there is nothing sensible for the arrow to point at, so it is hidden.
class PopoverPlacement {
  const PopoverPlacement({
    required this.offset,
    this.renderedSide,
    this.arrowSide,
    this.arrowOffset,
  });

  /// Top-left corner of the popover box.
  final Offset offset;

  /// The [Side] the popover actually ended up rendered on, after the
  /// preferred-side/fallback-order logic in [resolvePopoverPlacement] ran —
  /// may differ from the `side` that was requested if it didn't fit.
  final Side? renderedSide;

  /// Which popover edge the arrow sits on, per [resolveArrowSide] — usually
  /// [renderedSide] but can flip to the perpendicular edge when the element
  /// has scrolled clear of that side.
  final Side? arrowSide;

  /// Inline offset of the arrow along [arrowSide], as computed by
  /// [calculateArrowOffset]. Paired with [arrowSide]; both are `null`
  /// together.
  final double? arrowOffset;

  @override
  String toString() =>
      'PopoverPlacement(offset: $offset, renderedSide: $renderedSide, '
      'arrowSide: $arrowSide, arrowOffset: $arrowOffset)';
}

/// Computes where a popover of [popoverSize] should sit relative to
/// [element], choosing a side and alignment, exactly porting
/// `repositionPopover` from `position.ts` (minus the DOM writes).
///
/// - [offset] is the gap kept between the anchor's box and the popover; the
///   tour passes `stagePadding + popoverOffset` here.
/// - [padding] is how far an align start/end popover reaches past the
///   anchor's box; the tour passes `stagePadding` alone so the popover lines
///   up with the highlight cutout.
/// - [centered] centers the popover in [overlaySize] instead of positioning
///   it against [element] — used for the anchor-less, modal-like popover.
/// - Room tests are `edge - dims.size >= 0` style checks against
///   [overlaySize]; the fallback order when the preferred [side] doesn't fit
///   is left → right → top → bottom; if none fit, the popover is pinned
///   10px above the bottom edge, horizontally centered, with no arrow.
PopoverPlacement resolvePopoverPlacement({
  required Rect element,
  required Size popoverSize,
  required Size overlaySize,
  required Side side,
  required PopoverAlignment align,
  required double offset,
  required double padding,
  double arrowSize = kArrowSize,
  bool centered = false,
}) {
  final popoverWidthWithOffset = popoverSize.width + offset;
  final popoverHeightWithOffset = popoverSize.height + offset;

  final topValue = element.top - popoverHeightWithOffset;
  var isTopOptimal = topValue >= 0;

  final bottomValue =
      overlaySize.height - (element.bottom + popoverHeightWithOffset);
  var isBottomOptimal = bottomValue >= 0;

  final leftValue = element.left - popoverWidthWithOffset;
  var isLeftOptimal = leftValue >= 0;

  final rightValue =
      overlaySize.width - (element.right + popoverWidthWithOffset);
  var isRightOptimal = rightValue >= 0;

  final noneOptimal =
      !isTopOptimal && !isBottomOptimal && !isLeftOptimal && !isRightOptimal;

  // The preferred side wins outright if it has room; the others are then
  // disqualified so the chain below can't pick a different one.
  if (!centered) {
    if (side == Side.top && isTopOptimal) {
      isRightOptimal = isLeftOptimal = isBottomOptimal = false;
    } else if (side == Side.bottom && isBottomOptimal) {
      isRightOptimal = isLeftOptimal = isTopOptimal = false;
    } else if (side == Side.left && isLeftOptimal) {
      isRightOptimal = isTopOptimal = isBottomOptimal = false;
    } else if (side == Side.right && isRightOptimal) {
      isLeftOptimal = isTopOptimal = isBottomOptimal = false;
    }
  }

  double dx;
  double dy;
  Side? renderedSide;

  if (centered) {
    dx = overlaySize.width / 2 - popoverSize.width / 2;
    dy = overlaySize.height / 2 - popoverSize.height / 2;
  } else if (noneOptimal) {
    dx = overlaySize.width / 2 - popoverSize.width / 2;
    const bottomToSet = 10.0;
    dy = overlaySize.height - bottomToSet - popoverSize.height;
  } else if (isLeftOptimal) {
    dx = math.min(leftValue, overlaySize.width - popoverSize.width - arrowSize);
    dy = _topForLeftRight(
      align,
      element,
      popoverSize,
      padding,
      arrowSize,
      overlaySize,
    );
    renderedSide = Side.left;
  } else if (isRightOptimal) {
    final rightToSet = math.min(
      rightValue,
      overlaySize.width - popoverSize.width - arrowSize,
    );
    dx = overlaySize.width - rightToSet - popoverSize.width;
    dy = _topForLeftRight(
      align,
      element,
      popoverSize,
      padding,
      arrowSize,
      overlaySize,
    );
    renderedSide = Side.right;
  } else if (isTopOptimal) {
    dy = math.min(
      topValue,
      overlaySize.height - popoverSize.height - arrowSize,
    );
    dx = _leftForTopBottom(
      align,
      element,
      popoverSize,
      padding,
      arrowSize,
      overlaySize,
    );
    renderedSide = Side.top;
  } else {
    // By elimination this is the `isBottomOptimal` branch: `noneOptimal` was
    // false (so at least one side was originally optimal) and left/right/top
    // have all been ruled out above, so bottom must be the one — same
    // guarantee `repositionPopover`'s `else if (isBottomOptimal)` relies on.
    assert(isBottomOptimal);
    final bottomToSet = math.min(
      bottomValue,
      overlaySize.height - popoverSize.height - arrowSize,
    );
    dy = overlaySize.height - bottomToSet - popoverSize.height;
    dx = _leftForTopBottom(
      align,
      element,
      popoverSize,
      padding,
      arrowSize,
      overlaySize,
    );
    renderedSide = Side.bottom;
  }

  final position = Offset(dx, dy);

  if (renderedSide == null) {
    // Centered or pinned: nothing sensible for the arrow to point at.
    return PopoverPlacement(offset: position);
  }

  final popoverRect = position & popoverSize;
  final arrowSide = resolveArrowSide(renderedSide, element, popoverRect);

  final double arrowOffsetValue;
  if (arrowSide == Side.left || arrowSide == Side.right) {
    final target = calculateArrowTarget(
      element.top,
      element.bottom,
      popoverRect.top,
      popoverRect.bottom,
      align,
      arrowSize: arrowSize,
    );
    arrowOffsetValue = calculateArrowOffset(
      target,
      popoverRect.height,
      arrowSize: arrowSize,
    );
  } else {
    final target = calculateArrowTarget(
      element.left,
      element.right,
      popoverRect.left,
      popoverRect.right,
      align,
      arrowSize: arrowSize,
    );
    arrowOffsetValue = calculateArrowOffset(
      target,
      popoverRect.width,
      arrowSize: arrowSize,
    );
  }

  return PopoverPlacement(
    offset: position,
    renderedSide: renderedSide,
    arrowSide: arrowSide,
    arrowOffset: arrowOffsetValue,
  );
}

/// Cross-axis (vertical) placement for a popover rendered on the left/right
/// side of its anchor. Mirrors `calculateTopForLeftRight` in `position.ts`.
double _topForLeftRight(
  PopoverAlignment alignment,
  Rect element,
  Size popoverSize,
  double popoverPadding,
  double arrowSize,
  Size overlaySize,
) {
  switch (alignment) {
    case PopoverAlignment.start:
      return math.max(
        math.min(
          element.top - popoverPadding,
          overlaySize.height - popoverSize.height - arrowSize,
        ),
        arrowSize,
      );
    case PopoverAlignment.end:
      return math.max(
        math.min(
          element.top - popoverSize.height + element.height + popoverPadding,
          overlaySize.height - popoverSize.height - arrowSize,
        ),
        arrowSize,
      );
    case PopoverAlignment.center:
      return math.max(
        math.min(
          element.top + element.height / 2 - popoverSize.height / 2,
          overlaySize.height - popoverSize.height - arrowSize,
        ),
        arrowSize,
      );
  }
}

/// Cross-axis (horizontal) placement for a popover rendered on the
/// top/bottom side of its anchor. Mirrors `calculateLeftForTopBottom` in
/// `position.ts`.
double _leftForTopBottom(
  PopoverAlignment alignment,
  Rect element,
  Size popoverSize,
  double popoverPadding,
  double arrowSize,
  Size overlaySize,
) {
  switch (alignment) {
    case PopoverAlignment.start:
      return math.max(
        math.min(
          element.left - popoverPadding,
          overlaySize.width - popoverSize.width - arrowSize,
        ),
        arrowSize,
      );
    case PopoverAlignment.end:
      return math.max(
        math.min(
          element.left - popoverSize.width + element.width + popoverPadding,
          overlaySize.width - popoverSize.width - arrowSize,
        ),
        arrowSize,
      );
    case PopoverAlignment.center:
      return math.max(
        math.min(
          element.left + element.width / 2 - popoverSize.width / 2,
          overlaySize.width - popoverSize.width - arrowSize,
        ),
        arrowSize,
      );
  }
}
