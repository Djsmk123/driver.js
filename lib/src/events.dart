/// Frame-coalesced refresh scheduling and a metrics observer that triggers
/// it, ported from `events.ts`'s `requireRefresh` and its `resize`/`scroll`
/// listeners (design decision #5 in the plan). Keyboard handling and the
/// focus trap (`onKeyup`/`trapFocus` in `events.ts`) are M3 scope.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Coalesces bursts of refresh requests into a single post-frame refresh,
/// mirroring `requireRefresh` in `events.ts` (which cancels a pending
/// `requestAnimationFrame` and schedules a new one on every call, so N
/// resize/scroll events in the same tick only trigger one
/// `refreshActiveHighlight`).
///
/// Flutter's `addPostFrameCallback` has no cancel handle the way
/// `cancelAnimationFrame` does, so this coalesces with a generation counter
/// instead: each [requestRefresh] bumps [_generation]; when the scheduled
/// callback finally runs, it only invokes [onRefresh] if it's still the
/// most recent request — otherwise it re-arms so the newest request still
/// gets served.
class RefreshScheduler {
  RefreshScheduler(this.onRefresh);

  final VoidCallback onRefresh;

  int _generation = 0;
  bool _scheduled = false;
  bool _disposed = false;

  /// Requests a refresh. Safe to call many times per frame — only the last
  /// request in a given scheduling window actually runs.
  void requestRefresh() {
    if (_disposed) return;
    _generation++;
    _scheduleIfNeeded();
  }

  void _scheduleIfNeeded() {
    if (_scheduled) return;
    _scheduled = true;
    final requestedGeneration = _generation;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      if (requestedGeneration != _generation) {
        // Superseded by another requestRefresh() before this frame ran —
        // re-arm for the newest one instead of firing a stale refresh.
        _scheduleIfNeeded();
        return;
      }
      onRefresh();
    });
    // addPostFrameCallback only fires after a frame actually happens;
    // force one so a refresh requested outside of Flutter's normal build
    // cycle (e.g. from a `WidgetsBindingObserver.didChangeMetrics` call)
    // still lands promptly, mirroring `requestAnimationFrame`'s guarantee.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Stops any pending refresh from running. Call on `destroy()`.
  void dispose() {
    _disposed = true;
  }
}

/// Requests a refresh whenever the window/view metrics change (resize,
/// rotation, on-screen keyboard, browser zoom) — the Flutter analogue of
/// `events.ts`'s `window.addEventListener("resize", ...)`. There is no
/// Flutter-wide "scroll happened anywhere" notification to mirror the
/// paired `scroll` listener with (the root overlay entry never receives
/// the app's `ScrollNotification`s — see design decision #5); scroll
/// tracking during an active highlight is instead handled by the stage
/// ticker re-reading the live target rect every tick while animating
/// (`highlight.dart`), with continuous passive tracking after a transition
/// settles landing in M4 alongside the rest of the scroll work.
class DriverMetricsObserver extends WidgetsBindingObserver {
  DriverMetricsObserver(this._scheduler);

  final RefreshScheduler _scheduler;

  @override
  void didChangeMetrics() => _scheduler.requestRefresh();
}
