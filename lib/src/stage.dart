/// Pure geometry of the stage — the cutout in the full-screen dim that keeps
/// the highlighted element visible. Shared by the tour and hints overlays,
/// each passing its own padding and radius. Ported from driver.js's
/// `stage.ts`.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Grows [target] by [padding] on every side — the highlighted "stage" rect
/// before the corner radius is applied. Mirrors `stage.ts`'s
/// `stageWidth = stage.width + stagePadding * 2` (and the matching height /
/// x / y adjustments), which is exactly what [Rect.inflate] computes.
Rect inflateStage(Rect target, double padding) => target.inflate(padding);

/// Clamps [radius] so a rounded rect of [width]x[height] never glitches from
/// a radius larger than half of either dimension, and floors the result.
///
/// Mirrors `stage.ts`'s
/// `Math.floor(Math.max(Math.min(radius, width / 2, height / 2), 0))`
/// exactly, including the `Math.floor` (via [double.floorToDouble]).
double clampStageRadius(double radius, double width, double height) {
  final limitedRadius = math.min(radius, math.min(width / 2, height / 2));
  return math.max(limitedRadius, 0).floorToDouble();
}

/// Builds the full-screen dim path with a rounded-rect cutout for [target],
/// using [PathFillType.evenOdd] so the cutout is excluded from the fill.
///
/// Mirrors `stage.ts`'s `generateStageSvgPathString`. Because the path uses
/// evenodd fill, `path.contains(point)` doubles as the hit-test oracle: it
/// is `true` for points in the dim region and `false` for points inside the
/// cutout hole, which is exactly the dim/hole hit-testing split
/// [RenderOverlayCutout][] needs and what the unit tests exercise directly
/// via [Path.contains].
///
/// [screenSize] is the full overlay size (the JS version reads
/// `window.innerWidth`/`innerHeight`; the overlay-local equivalent is the
/// render box's own [size]). [padding] and [radius] are the tour/hint's
/// `stagePadding`/`stageRadius`.
Path buildStagePath({
  required Size screenSize,
  required Rect target,
  required double padding,
  required double radius,
}) {
  final stage = inflateStage(target, padding);
  final normalizedRadius = clampStageRadius(radius, stage.width, stage.height);

  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & screenSize)
    ..addRRect(
      RRect.fromRectAndRadius(stage, Radius.circular(normalizedRadius)),
    );
}
