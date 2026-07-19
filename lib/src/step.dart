/// A single tour/highlight step. Minimal M1 shape — enough to compile and
/// to drive `highlight()`/`destroy()`/`refresh()`. Ported from `step.ts`'s
/// `DriveStep` type; the resolution helpers that live alongside it in
/// `step.ts` (`resolveTourStep`, `shouldSkipStep`, `findReachableIndex`,
/// button/progress-text quirks — design decision #6 in the plan) land in
/// M3 together with tour navigation.
library;

import 'config.dart';
import 'popover.dart';

/// One step of a tour, or the argument to `Driver.highlight()` for a
/// single, tour-less highlight.
class DriveStep {
  const DriveStep({
    this.element,
    this.popover,
    this.disableActiveInteraction,
    this.advanceOnClick,
    this.skipMissingElement,
    this.waitForElement,
    this.data,
    this.onHighlightStarted,
    this.onHighlighted,
    this.onDeselected,
  });

  /// The element to highlight: a [GlobalKey], a [BuildContext], a zero-arg
  /// function returning either of those (or `null`), or `null` itself.
  /// Resolved via `resolveTargetContext` in `utils.dart`. `null` produces
  /// an element-less "centered" step, mirroring driver.js's dummy
  /// zero-size div mounted at the viewport center for a selector that
  /// resolves to nothing (see `highlight.dart`).
  final Object? element;

  /// Per-step popover configuration. `null` means this step highlights
  /// without ever showing a popover (driver.js's bare, buttonless
  /// `highlight()` usage — see design decision #6).
  final DriverPopover? popover;

  /// Overrides `DriverConfig.disableActiveInteraction` for this step.
  final bool? disableActiveInteraction;

  /// Overrides `DriverConfig.advanceOnClick` for this step. Wiring this up
  /// to actually advance a tour is M3/M4 scope.
  final bool? advanceOnClick;

  /// Overrides `DriverConfig.skipMissingElement` for this step. Only
  /// meaningful once tour navigation (M3) can skip steps.
  final bool? skipMissingElement;

  /// Overrides `DriverConfig.waitForElement` for this step. Wired up in
  /// M4 alongside `waitForElement` polling.
  final Duration? waitForElement;

  /// Arbitrary user data threaded through to hooks via `DriveStep`, mirrors
  /// `step.ts`'s `data` field.
  final Map<String, Object?>? data;

  final DriverHook? onHighlightStarted;
  final DriverHook? onHighlighted;
  final DriverHook? onDeselected;
}
