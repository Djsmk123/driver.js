/// Visual constants derived from driver.js's `driver.css`, threaded through
/// the overlay/highlight subsystem so callers can override the look without
/// touching the geometry code in `stage.dart`/`overlay_widget.dart`.
///
/// This is intentionally minimal for M1 — just the values the cutout
/// painter needs. Popover/hint theming (colors, fonts, spacing, button
/// styles) lands alongside those widgets in M2/M5, at which point this
/// class grows the corresponding fields (see the plan's design decision
/// #13).
library;

import 'dart:ui';

/// Config < step < hint level theme overrides for the overlay/highlight
/// visuals. Mirrors the CSS custom properties driver.css exposes via
/// `overlayColor`/`overlayOpacity`/`stagePadding`/`stageRadius` config
/// fields, collected here so `DriverConfig` (and later per-step overrides)
/// can hand a single object to the overlay widget.
class DriverTheme {
  const DriverTheme({
    this.overlayColor = const Color(0xFF000000),
    this.overlayOpacity = 0.7,
    this.stagePadding = 10,
    this.stageRadius = 5,
  });

  /// Fill color of the full-screen dim. Defaults to `#000`, matching
  /// `driver.css`/the config store's `overlayColor` default.
  final Color overlayColor;

  /// Opacity applied to [overlayColor]. Defaults to `0.7`, matching the
  /// config store's `overlayOpacity` default.
  final double overlayOpacity;

  /// How far the stage cutout grows past the highlighted element's bounds
  /// on every side. Defaults to `10`, matching `stagePadding`.
  final double stagePadding;

  /// Corner radius of the stage cutout before the `stage.dart` clamp is
  /// applied. Defaults to `5`, matching `stageRadius`.
  final double stageRadius;

  DriverTheme copyWith({
    Color? overlayColor,
    double? overlayOpacity,
    double? stagePadding,
    double? stageRadius,
  }) {
    return DriverTheme(
      overlayColor: overlayColor ?? this.overlayColor,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      stagePadding: stagePadding ?? this.stagePadding,
      stageRadius: stageRadius ?? this.stageRadius,
    );
  }

  @override
  String toString() =>
      'DriverTheme(overlayColor: $overlayColor, overlayOpacity: $overlayOpacity, '
      'stagePadding: $stagePadding, stageRadius: $stageRadius)';
}
