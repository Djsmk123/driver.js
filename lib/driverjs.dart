/// A Flutter port of driver.js — product tours, single-element highlights,
/// and pulsing hint beacons, with an API that mirrors the driver.js
/// JavaScript library.
///
/// See the top-level `driver()` and `hints()` factories for the two entry
/// points.
library;

// Exports are added milestone by milestone as each subsystem lands; see
// /Users/smkwinner/.claude/plans/git-github-com-nilbuild-driver-js-git-cl-curried-kurzweil.md

// M1: geometry + overlay + highlight core.
export 'src/config.dart'
    show
        DriverButton,
        DriverConfig,
        DriverHook,
        DriverHookOpts,
        OverlayClickBehavior,
        OverlayClickBehaviorClose,
        OverlayClickBehaviorCustom,
        OverlayClickBehaviorNextStep;
export 'src/driver.dart' show Driver, driver;
export 'src/position.dart' show PopoverAlignment, PopoverPlacement, Side;
export 'src/state.dart' show DriverState;
export 'src/step.dart' show DriveStep;
export 'src/theme.dart' show DriverTheme;

// M2: popover.
export 'src/popover.dart'
    show
        DriverPopover,
        DriverPopoverBuilder,
        DriverPopoverData,
        PopoverRenderHook;
export 'src/popover_widget.dart'
    show DriverPopoverContent, PopoverPositioner, RenderPopoverPositioner;

// M5: hints.
export 'src/hint_widgets.dart' show HintBeacon, HintBeaconStyle, HintPopover;
export 'src/hints.dart'
    show
        DriverHint,
        HintHook,
        HintHookOpts,
        HintPopoverRenderHook,
        Hints,
        HintsConfig,
        hints;

// Internal-only: context.dart, events.dart, highlight.dart,
// overlay_widget.dart, registry.dart, stage.dart, utils.dart. These
// implement the public surface above but aren't meant to be constructed/
// called directly by package users.
