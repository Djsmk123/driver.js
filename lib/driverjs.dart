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
        DriverPopoverBuilder,
        OverlayClickBehavior,
        OverlayClickBehaviorClose,
        OverlayClickBehaviorCustom,
        OverlayClickBehaviorNextStep,
        PopoverRenderHook;
export 'src/driver.dart' show Driver, driver;
export 'src/position.dart' show PopoverAlignment, PopoverPlacement, Side;
export 'src/state.dart' show DriverState;
export 'src/step.dart' show DriveStep;
export 'src/theme.dart' show DriverTheme;

// Internal-only: context.dart, events.dart, highlight.dart, overlay_widget.dart,
// stage.dart, utils.dart. These implement the public surface above but
// aren't meant to be constructed/called directly by package users.
