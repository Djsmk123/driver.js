/// `DriverConfig` and its supporting types, ported from `context.ts`'s
/// `Config` type (plus the button/hook enums the plan's public API sketch
/// hangs off it). All defaults mirror `createConfigStore`'s `configure()`
/// defaults exactly.
///
/// This file defines the full data shape from the plan's API sketch so
/// later milestones don't need to keep widening `DriverConfig` — but only
/// M1's subset (overlay/highlight fields) does anything yet. Button/step
/// resolution (M3), popover rendering (M2) and hints (M5) consume the rest.
library;

import 'package:flutter/widgets.dart';

import 'driver.dart';
import 'state.dart';
import 'step.dart';
import 'theme.dart';

/// One of the three buttons driver.js's default popover footer can show.
/// Mirrors `AllowedButtons` in `popover.ts`.
enum DriverButton { next, previous, close }

/// A resolved hook signature shared by every `DriverConfig`/`DriveStep`
/// lifecycle and click callback. Mirrors `DriverHook` in `context.ts`.
///
/// [element] is `null` for an element-less (centered/dummy) step, matching
/// the JS hook's `element: Element | undefined` for the same case.
typedef DriverHook =
    void Function(BuildContext? element, DriveStep step, DriverHookOpts opts);

/// Extra context handed to every [DriverHook] call, mirroring `HookOpts` in
/// `context.ts`.
class DriverHookOpts {
  const DriverHookOpts({
    required this.config,
    required this.state,
    required this.driver,
    this.index,
  });

  final DriverConfig config;
  final DriverState state;
  final Driver driver;

  /// The active step index at the time the hook fired, or `null` outside a
  /// tour (e.g. a bare `highlight()` call).
  final int? index;
}

/// What happens when the dim region of the overlay (outside the highlighted
/// stage) is tapped. Mirrors `Config["overlayClickBehavior"]`'s
/// `"close" | "nextStep" | DriverHook` union — modeled here as a small
/// sealed hierarchy instead of a string-or-function union so call sites get
/// exhaustive `switch` checking.
sealed class OverlayClickBehavior {
  const OverlayClickBehavior();

  /// Destroy the driver (subject to `allowClose`). The default, matching
  /// JS's `"close"`.
  const factory OverlayClickBehavior.close() = OverlayClickBehaviorClose;

  /// Advance to the next step (or the resolved next/done hook), matching
  /// JS's `"nextStep"`. Only meaningful within a tour (M3).
  const factory OverlayClickBehavior.nextStep() = OverlayClickBehaviorNextStep;

  /// Run an arbitrary [DriverHook] instead, matching JS's function form.
  const factory OverlayClickBehavior.custom(DriverHook handler) =
      OverlayClickBehaviorCustom;
}

final class OverlayClickBehaviorClose extends OverlayClickBehavior {
  const OverlayClickBehaviorClose();
}

final class OverlayClickBehaviorNextStep extends OverlayClickBehavior {
  const OverlayClickBehaviorNextStep();
}

final class OverlayClickBehaviorCustom extends OverlayClickBehavior {
  const OverlayClickBehaviorCustom(this.handler);
  final DriverHook handler;
}

/// Placeholder for M2's popover builder signature (`DriverPopoverBuilder`
/// in the plan's public API sketch: `Widget Function(DriverPopoverData
/// data, DriverHookOpts opts)`). Typed as a plain zero-arg widget builder
/// for now, since `DriverPopoverData` doesn't exist until M2 — the field
/// exists on `DriverConfig` today only so the config surface matches the
/// plan; nothing reads it in M1.
typedef DriverPopoverBuilder = Widget Function();

/// Placeholder for M2's `onPopoverRender` hook signature
/// (`(popover: PopoverDOM, opts: HookOpts) => void` in `context.ts`).
typedef PopoverRenderHook =
    void Function(Object popoverData, DriverHookOpts opts);

/// Tour/highlight configuration, mirroring `Config` in `context.ts`. Every
/// default below matches `createConfigStore`'s `configure()` defaults
/// (`overlayColor: "#000"`, `duration: 400`, etc.) so an un-configured
/// `driver()` behaves like an un-configured JS `driver()`.
///
/// `DriverContext.setConfig` replaces the whole object rather than merging
/// (design decision #9 / context.ts's "wholesale replace" semantics) — this
/// class's own defaulted constructor is what makes that safe: a
/// `DriverConfig()` with only a couple of fields set still gets every other
/// field's default, exactly like JS's `{ ...defaults, ...config }` spread.
class DriverConfig {
  const DriverConfig({
    this.steps,
    this.animate = true,
    this.duration = const Duration(milliseconds: 400),
    this.overlayColor = const Color(0xFF000000),
    this.overlayOpacity = 0.7,
    this.smoothScroll = false,
    this.allowClose = true,
    this.allowScroll = true,
    this.overlayClickBehavior = const OverlayClickBehavior.close(),
    this.stagePadding = 10,
    this.stageRadius = 5,
    this.popoverOffset = 10,
    this.disableActiveInteraction = false,
    this.advanceOnClick = false,
    this.skipMissingElement = false,
    this.waitForElement = Duration.zero,
    this.allowKeyboardControl = true,
    this.showButtons = const [
      DriverButton.next,
      DriverButton.previous,
      DriverButton.close,
    ],
    this.disableButtons = const [],
    this.showProgress = false,
    this.progressText,
    this.nextBtnText,
    this.prevBtnText,
    this.doneBtnText,
    this.theme,
    this.popoverBuilder,
    this.context,
    this.onPopoverRender,
    this.onHighlightStarted,
    this.onHighlighted,
    this.onDeselected,
    this.onDestroyStarted,
    this.onDestroyed,
    this.onNextClick,
    this.onPrevClick,
    this.onCloseClick,
    this.onDoneClick,
  });

  /// Tour steps. `null`/empty means "highlight-only" usage via
  /// `Driver.highlight()` — full tour navigation is M3.
  final List<DriveStep>? steps;

  /// Whether the stage/popover transition animates at all. When `false`
  /// the stage snaps instantly and no fade plays (design decision #3).
  final bool animate;

  /// Length of the stage-chase animation and the one-time overlay fade-in.
  final Duration duration;

  /// Fill color of the full-screen dim.
  final Color overlayColor;

  /// Opacity applied to [overlayColor].
  final double overlayOpacity;

  /// Whether scrolling to bring a step's element into view animates
  /// (`Scrollable.ensureVisible`'s curve/duration) or jumps. M4 scope.
  final bool smoothScroll;

  /// Whether Escape / the overlay's `close` click behavior / the popover's
  /// `x` button are allowed to destroy the driver.
  final bool allowClose;

  /// Whether the page may scroll while a highlight is active. M4 scope
  /// (design decision #11); unused by M1's overlay.
  final bool allowScroll;

  /// What a tap on the dim region (outside the stage) does.
  final OverlayClickBehavior overlayClickBehavior;

  /// How far the stage cutout grows past the highlighted element on every
  /// side.
  final double stagePadding;

  /// Corner radius of the stage cutout (clamped by `stage.dart`).
  final double stageRadius;

  /// Gap kept between the stage and the popover. M2 scope.
  final double popoverOffset;

  /// When `true`, the highlighted element itself doesn't receive taps
  /// (hole hit-testing swallows them instead of passing through — see
  /// design decision #4).
  final bool disableActiveInteraction;

  /// Advance the tour when the highlighted element itself is tapped. The
  /// element's own tap behavior still runs; nothing is intercepted. Wiring
  /// this to actual advancement is M3/M4 scope.
  final bool advanceOnClick;

  /// Skip a step whose element is specified but missing, instead of
  /// falling back to a centered dummy highlight. M3 scope (tour skip
  /// walks).
  final bool skipMissingElement;

  /// Wait up to this long for a step's missing element to appear before
  /// falling back to the usual missing-element behavior. M4 scope.
  final Duration waitForElement;

  /// Whether Escape/arrow-key navigation is active. M3 scope.
  final bool allowKeyboardControl;

  /// Which buttons the default popover footer shows. M3 scope.
  final List<DriverButton> showButtons;

  /// Which buttons are rendered but disabled. M3 scope.
  final List<DriverButton> disableButtons;

  /// Whether the default popover footer shows a progress indicator. M3
  /// scope.
  final bool showProgress;

  final String? progressText;
  final String? nextBtnText;
  final String? prevBtnText;
  final String? doneBtnText;

  /// Overlay/highlight (and later popover/hint) visual overrides. `null`
  /// uses `DriverTheme`'s own defaults.
  final DriverTheme? theme;

  /// Fully replaces the default popover content. M2 scope.
  final DriverPopoverBuilder? popoverBuilder;

  /// The [BuildContext] used to look up the root [Overlay] the highlight
  /// entry mounts into (design decision #1). When `null`, it's resolved
  /// from the first step/hint whose element resolves to a mounted context.
  final BuildContext? context;

  /// Called after the popover is (re)rendered. M2 scope.
  final PopoverRenderHook? onPopoverRender;

  final DriverHook? onHighlightStarted;
  final DriverHook? onHighlighted;
  final DriverHook? onDeselected;
  final DriverHook? onDestroyStarted;
  final DriverHook? onDestroyed;
  final DriverHook? onNextClick;
  final DriverHook? onPrevClick;
  final DriverHook? onCloseClick;
  final DriverHook? onDoneClick;
}
