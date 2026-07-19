/// Visual constants derived from driver.js's `driver.css`/`popover.css`,
/// threaded through the overlay/highlight/popover subsystems so callers can
/// override the look without touching the geometry code in
/// `stage.dart`/`position.dart`.
///
/// M1 only needed the dim/cutout fields. M2 adds every popover-visual field
/// `popover.css` hard-codes (background, padding, radii, shadow, font
/// sizes, button colors, close-button geometry) so `popover_widget.dart`'s
/// default content widget has somewhere themeable to read them from instead
/// of hard-coding the CSS values inline — matching design decision #13's
/// "DriverTheme holds all CSS-derived values" plus its `popoverBuilder`
/// slot (settable at config/step/theme level, per decision #8).
library;

import 'package:flutter/painting.dart';

import 'popover.dart';

/// Config < step < hint level theme overrides for the overlay/highlight and
/// popover visuals. Mirrors the CSS custom properties/hard-coded values
/// `driver.css` and `popover.css` expose, collected here so `DriverConfig`
/// (and later per-step/per-hint overrides) can hand a single object to the
/// overlay/popover widgets.
class DriverTheme {
  const DriverTheme({
    // Overlay/stage — M1.
    this.overlayColor = const Color(0xFF000000),
    this.overlayOpacity = 0.7,
    this.stagePadding = 10,
    this.stageRadius = 5,
    // Popover — M2, values lifted straight from popover.css.
    this.popoverBackgroundColor = const Color(0xFFFFFFFF),
    this.popoverTextColor = const Color(0xFF2D2D2D),
    this.popoverPadding = const EdgeInsets.all(15),
    this.popoverBorderRadius = 5,
    this.popoverMinWidth = 250,
    this.popoverMaxWidth = 300,
    this.popoverShadow = const [
      BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 1)),
    ],
    this.popoverTitleFontSize = 19,
    this.popoverDescriptionFontSize = 14,
    this.popoverProgressTextColor = const Color(0xFF727272),
    this.popoverProgressFontSize = 13,
    this.popoverButtonBorderColor = const Color(0xFFCCCCCC),
    this.popoverButtonBackgroundColor = const Color(0xFFFFFFFF),
    this.popoverButtonHoverBackgroundColor = const Color(0xFFF7F7F7),
    this.popoverButtonTextColor = const Color(0xFF2D2D2D),
    this.popoverButtonFontSize = 12,
    this.popoverButtonPadding = const EdgeInsets.symmetric(
      horizontal: 7,
      vertical: 3,
    ),
    this.popoverButtonBorderRadius = 3,
    this.popoverButtonSpacing = 4,
    this.popoverCloseButtonColor = const Color(0xFFD2D2D2),
    this.popoverCloseButtonHoverColor = const Color(0xFF2D2D2D),
    this.popoverCloseButtonSize = const Size(32, 28),
    this.popoverArrowSize = 10,
    this.popoverBuilder,
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

  /// `.driver-popover`'s `background-color: #fff`. Also the color the
  /// arrow triangle is painted, so it reads as part of the popover body.
  final Color popoverBackgroundColor;

  /// `.driver-popover`'s `color: #2d2d2d`.
  final Color popoverTextColor;

  /// `.driver-popover`'s `padding: 15px`.
  final EdgeInsets popoverPadding;

  /// `.driver-popover`'s `border-radius: 5px`.
  final double popoverBorderRadius;

  /// `.driver-popover`'s `min-width: 250px`.
  final double popoverMinWidth;

  /// `.driver-popover`'s `max-width: 300px`.
  final double popoverMaxWidth;

  /// `.driver-popover`'s `box-shadow: 0 1px 10px #0006`.
  final List<BoxShadow> popoverShadow;

  /// `.driver-popover-title`'s `font-size: 19px` (`font-weight: 700` and
  /// `line-height: 1.5` are applied directly in the content widget, not
  /// themed — they aren't values a caller plausibly wants to override
  /// independently of the font size).
  final double popoverTitleFontSize;

  /// `.driver-popover-description`'s `font-size: 14px`.
  final double popoverDescriptionFontSize;

  /// `.driver-popover-progress-text`'s `color: #727272`.
  final Color popoverProgressTextColor;

  /// `.driver-popover-progress-text`'s `font-size: 13px`.
  final double popoverProgressFontSize;

  /// `.driver-popover-footer-btn`'s `border: 1px solid #ccc`.
  final Color popoverButtonBorderColor;

  /// `.driver-popover-footer-btn`'s `background-color: #ffffff`.
  final Color popoverButtonBackgroundColor;

  /// `.driver-popover-footer-btn:hover`'s `background-color: #f7f7f7`.
  final Color popoverButtonHoverBackgroundColor;

  /// `.driver-popover-footer-btn`'s `color: #2d2d2d`.
  final Color popoverButtonTextColor;

  /// `.driver-popover-footer-btn`'s `font-size: 12px`.
  final double popoverButtonFontSize;

  /// `.driver-popover-footer-btn`'s `padding: 3px 7px`.
  final EdgeInsets popoverButtonPadding;

  /// `.driver-popover-footer-btn`'s `border-radius: 3px`.
  final double popoverButtonBorderRadius;

  /// `.driver-popover-navigation-btns button + button`'s `margin-left: 4px`.
  final double popoverButtonSpacing;

  /// `.driver-popover-close-btn`'s `color: #d2d2d2`.
  final Color popoverCloseButtonColor;

  /// `.driver-popover-close-btn:hover`'s `color: #2d2d2d`.
  final Color popoverCloseButtonHoverColor;

  /// `.driver-popover-close-btn`'s `width: 32px; height: 28px`.
  final Size popoverCloseButtonSize;

  /// Matches `position.dart`'s `kArrowSize` default (10x10 CSS border
  /// triangle). Kept themeable independently since hints (M5) use a
  /// differently-sized arrow (14) without a differently-sized popover box.
  final double popoverArrowSize;

  /// Fully replaces the default popover content widget for every popover
  /// using this theme, unless overridden by a more specific
  /// `DriverPopover.popoverBuilder`/`DriverConfig.popoverBuilder` (see
  /// design decision #8's config/step/theme precedence, resolved in
  /// `highlight.dart`).
  final DriverPopoverBuilder? popoverBuilder;

  DriverTheme copyWith({
    Color? overlayColor,
    double? overlayOpacity,
    double? stagePadding,
    double? stageRadius,
    Color? popoverBackgroundColor,
    Color? popoverTextColor,
    EdgeInsets? popoverPadding,
    double? popoverBorderRadius,
    double? popoverMinWidth,
    double? popoverMaxWidth,
    List<BoxShadow>? popoverShadow,
    double? popoverTitleFontSize,
    double? popoverDescriptionFontSize,
    Color? popoverProgressTextColor,
    double? popoverProgressFontSize,
    Color? popoverButtonBorderColor,
    Color? popoverButtonBackgroundColor,
    Color? popoverButtonHoverBackgroundColor,
    Color? popoverButtonTextColor,
    double? popoverButtonFontSize,
    EdgeInsets? popoverButtonPadding,
    double? popoverButtonBorderRadius,
    double? popoverButtonSpacing,
    Color? popoverCloseButtonColor,
    Color? popoverCloseButtonHoverColor,
    Size? popoverCloseButtonSize,
    double? popoverArrowSize,
    DriverPopoverBuilder? popoverBuilder,
  }) {
    return DriverTheme(
      overlayColor: overlayColor ?? this.overlayColor,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      stagePadding: stagePadding ?? this.stagePadding,
      stageRadius: stageRadius ?? this.stageRadius,
      popoverBackgroundColor:
          popoverBackgroundColor ?? this.popoverBackgroundColor,
      popoverTextColor: popoverTextColor ?? this.popoverTextColor,
      popoverPadding: popoverPadding ?? this.popoverPadding,
      popoverBorderRadius: popoverBorderRadius ?? this.popoverBorderRadius,
      popoverMinWidth: popoverMinWidth ?? this.popoverMinWidth,
      popoverMaxWidth: popoverMaxWidth ?? this.popoverMaxWidth,
      popoverShadow: popoverShadow ?? this.popoverShadow,
      popoverTitleFontSize: popoverTitleFontSize ?? this.popoverTitleFontSize,
      popoverDescriptionFontSize:
          popoverDescriptionFontSize ?? this.popoverDescriptionFontSize,
      popoverProgressTextColor:
          popoverProgressTextColor ?? this.popoverProgressTextColor,
      popoverProgressFontSize:
          popoverProgressFontSize ?? this.popoverProgressFontSize,
      popoverButtonBorderColor:
          popoverButtonBorderColor ?? this.popoverButtonBorderColor,
      popoverButtonBackgroundColor:
          popoverButtonBackgroundColor ?? this.popoverButtonBackgroundColor,
      popoverButtonHoverBackgroundColor:
          popoverButtonHoverBackgroundColor ??
          this.popoverButtonHoverBackgroundColor,
      popoverButtonTextColor:
          popoverButtonTextColor ?? this.popoverButtonTextColor,
      popoverButtonFontSize:
          popoverButtonFontSize ?? this.popoverButtonFontSize,
      popoverButtonPadding: popoverButtonPadding ?? this.popoverButtonPadding,
      popoverButtonBorderRadius:
          popoverButtonBorderRadius ?? this.popoverButtonBorderRadius,
      popoverButtonSpacing: popoverButtonSpacing ?? this.popoverButtonSpacing,
      popoverCloseButtonColor:
          popoverCloseButtonColor ?? this.popoverCloseButtonColor,
      popoverCloseButtonHoverColor:
          popoverCloseButtonHoverColor ?? this.popoverCloseButtonHoverColor,
      popoverCloseButtonSize:
          popoverCloseButtonSize ?? this.popoverCloseButtonSize,
      popoverArrowSize: popoverArrowSize ?? this.popoverArrowSize,
      popoverBuilder: popoverBuilder ?? this.popoverBuilder,
    );
  }

  @override
  String toString() =>
      'DriverTheme(overlayColor: $overlayColor, overlayOpacity: $overlayOpacity, '
      'stagePadding: $stagePadding, stageRadius: $stageRadius, '
      'popoverBackgroundColor: $popoverBackgroundColor)';
}
