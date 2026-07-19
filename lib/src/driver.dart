/// The public `Driver` API and the `driver()` factory, ported from
/// `driver.ts`. M1 implements only the highlight-only subset described in
/// the plan's milestone list: `highlight`, `destroy`, `refresh`,
/// `isActive`, and the mount/context resolution design decision #1
/// describes. Every tour-navigation method (`drive`, `moveNext`,
/// `movePrevious`, `moveTo`, `hasNextStep`, …) throws
/// [UnimplementedError] until M3 lands `step.dart`'s button/progress
/// resolution and the navigation flow in design decision #9.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'context.dart';
import 'events.dart';
import 'highlight.dart';
import 'overlay_widget.dart';
import 'state.dart';
import 'step.dart';
import 'theme.dart';
import 'utils.dart';

/// The public driver.js-mirroring API. See the plan's public API sketch
/// for the full shape this grows into across M1-M4; only the subset
/// documented on each method below is implemented in M1.
abstract class Driver {
  /// Starts (or restarts) a tour at [stepIndex]. M3.
  void drive([int stepIndex = 0]);

  /// Highlights a single element, independent of any tour. Mounts the
  /// overlay (resolving a [BuildContext] to attach it to per design
  /// decision #1) if it isn't already, then animates the stage to [step]'s
  /// element.
  void highlight(DriveStep step);

  /// Advances to the next tour step. M3.
  void moveNext();

  /// Returns to the previous tour step. M3.
  void movePrevious();

  /// Jumps to tour step [index]. M3.
  void moveTo(int index);

  /// Whether a next tour step exists. M3.
  bool hasNextStep();

  /// Whether a previous tour step exists. M3.
  bool hasPreviousStep();

  /// Whether the active step is the tour's first reachable step. M3.
  bool isFirstStep();

  /// Whether the active step is the tour's last reachable step. M3.
  bool isLastStep();

  /// The step passed to the most recent `highlight()`/`drive()` call.
  DriveStep? getActiveStep();

  /// The element passed to the most recent `highlight()`/`drive()` call.
  BuildContext? getActiveElement();

  /// The previously *visited* step (not simply `index - 1`). M3.
  DriveStep? getPreviousStep();

  /// The previously *visited* element (not simply `index - 1`). M3.
  BuildContext? getPreviousElement();

  /// The next step a tour would move to. M3.
  DriveStep? getNextStep();

  /// The active tour step index, or `null` outside a tour.
  int? getActiveIndex();

  /// The driver's mutable runtime state.
  DriverState getState();

  /// The driver's current config.
  DriverConfig getConfig();

  /// Replaces the config wholesale (design decision #9's "wholesale
  /// replace", not a merge).
  void setConfig(DriverConfig config);

  /// Replaces the tour's steps, resetting tour state but keeping config.
  /// M3.
  void setSteps(List<DriveStep> steps);

  /// Requests a frame-coalesced re-sync of the stage to the active
  /// element's current rect (`RefreshScheduler` in `events.dart`).
  void refresh();

  /// Whether the overlay is currently mounted.
  bool isActive();

  /// Tears down the overlay and resets state. Unlike JS's `destroy()`,
  /// this never runs `onDestroyStarted` (that hook only fires for
  /// user-initiated closes — Esc, the popover's `x`, an overlay-click
  /// close — which don't exist until M2/M3 wire them up; see design
  /// decision #9).
  void destroy();
}

/// Creates a [Driver], mirroring the `driver(options)` factory in
/// `driver.ts`.
Driver driver([DriverConfig config = const DriverConfig()]) =>
    _DriverImpl(config);

class _DriverImpl implements Driver {
  _DriverImpl(DriverConfig config) : _ctx = DriverContext(config) {
    _ctx.driver = this;
  }

  final DriverContext _ctx;

  final GlobalKey<DriverOverlayState> _overlayKey =
      GlobalKey<DriverOverlayState>();
  OverlayEntry? _entry;
  RefreshScheduler? _refreshScheduler;
  DriverMetricsObserver? _metricsObserver;

  @override
  void highlight(DriveStep step) {
    final mountContext = _resolveMountContext(step);
    if (mountContext == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'driverjs: could not resolve a BuildContext to mount the overlay.',
        ),
        ErrorDescription(
          'Pass `context:` in DriverConfig, or make sure the step\'s '
          '`element` resolves to a mounted widget before calling '
          'highlight().',
        ),
      ]);
    }

    _ensureMounted(mountContext);

    // Geometry can only be read once the overlay entry has actually built
    // and laid out, which happens after this frame's build/layout/paint —
    // so the real work is deferred to a post-frame callback rather than
    // done inline.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _performHighlight(step),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _performHighlight(DriveStep step) {
    final overlay = _overlayKey.currentState;
    if (overlay == null) {
      // The entry hasn't finished building yet (e.g. it was only just
      // inserted this same frame, ahead of the callback above) — retry on
      // the next frame rather than silently dropping the highlight.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _performHighlight(step),
      );
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    transferHighlight(_ctx, step, overlay);
  }

  BuildContext? _resolveMountContext(DriveStep step) {
    final configContext = _ctx.config.context;
    if (configContext != null && configContext.mounted) {
      return configContext;
    }
    return resolveTargetContext(step.element);
  }

  void _ensureMounted(BuildContext mountContext) {
    if (_entry != null) return;

    final overlayState = Overlay.of(mountContext, rootOverlay: true);
    final theme = _ctx.config.theme ?? const DriverTheme();

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: DriverOverlay(
            key: _overlayKey,
            initialStageRect: Rect.zero,
            theme: theme,
            disableActiveInteraction: _ctx.config.disableActiveInteraction,
            fadeInDuration: _ctx.config.duration,
            animateFadeIn: _ctx.config.animate,
            onOverlayTap: _handleOverlayTap,
          ),
        );
      },
    );
    overlayState.insert(_entry!);
    _ctx.state.isInitialized = true;

    _refreshScheduler = RefreshScheduler(_handleRefresh);
    _metricsObserver = DriverMetricsObserver(_refreshScheduler!);
    WidgetsBinding.instance.addObserver(_metricsObserver!);
  }

  void _handleRefresh() {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    refreshActiveHighlight(_ctx, overlay);
  }

  void _handleOverlayTap() {
    final behavior = _ctx.config.overlayClickBehavior;
    switch (behavior) {
      case OverlayClickBehaviorClose():
        if (_ctx.config.allowClose) destroy();
      case OverlayClickBehaviorCustom(:final handler):
        final step = _ctx.state.activeStep;
        if (step != null) {
          handler(_ctx.state.activeElement, step, _ctx.getHookOpts());
        }
      case OverlayClickBehaviorNextStep():
        // Advancing a tour is M3 scope; nothing to advance to yet outside
        // one.
        break;
    }
  }

  @override
  void refresh() => _refreshScheduler?.requestRefresh();

  @override
  bool isActive() => _entry != null;

  @override
  void destroy() {
    if (_entry == null) return;

    if (_metricsObserver != null) {
      WidgetsBinding.instance.removeObserver(_metricsObserver!);
      _metricsObserver = null;
    }
    _refreshScheduler?.dispose();
    _refreshScheduler = null;

    _entry!.remove();
    _entry = null;

    _ctx.state.reset();
    _ctx.resetEmitter();
  }

  @override
  DriveStep? getActiveStep() => _ctx.state.activeStep;

  @override
  BuildContext? getActiveElement() => _ctx.state.activeElement;

  @override
  int? getActiveIndex() => _ctx.state.activeIndex;

  @override
  DriverState getState() => _ctx.state;

  @override
  DriverConfig getConfig() => _ctx.config;

  @override
  void setConfig(DriverConfig config) => _ctx.setConfig(config);

  @override
  void drive([int stepIndex = 0]) =>
      throw UnimplementedError('drive() lands in M3');

  @override
  void moveNext() => throw UnimplementedError('moveNext() lands in M3');

  @override
  void movePrevious() => throw UnimplementedError('movePrevious() lands in M3');

  @override
  void moveTo(int index) => throw UnimplementedError('moveTo() lands in M3');

  @override
  bool hasNextStep() => throw UnimplementedError('hasNextStep() lands in M3');

  @override
  bool hasPreviousStep() =>
      throw UnimplementedError('hasPreviousStep() lands in M3');

  @override
  bool isFirstStep() => throw UnimplementedError('isFirstStep() lands in M3');

  @override
  bool isLastStep() => throw UnimplementedError('isLastStep() lands in M3');

  @override
  DriveStep? getPreviousStep() =>
      throw UnimplementedError('getPreviousStep() lands in M3');

  @override
  BuildContext? getPreviousElement() =>
      throw UnimplementedError('getPreviousElement() lands in M3');

  @override
  DriveStep? getNextStep() =>
      throw UnimplementedError('getNextStep() lands in M3');

  @override
  void setSteps(List<DriveStep> steps) =>
      throw UnimplementedError('setSteps() lands in M3');
}
