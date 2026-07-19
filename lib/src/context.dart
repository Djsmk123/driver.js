/// Per-instance store threading [DriverConfig], [DriverState] and a small
/// event emitter through the overlay/highlight helpers, ported from
/// `context.ts`'s `createContext`.
///
/// Everything here is instance state — no module-level globals — so each
/// `Driver` owns its own `DriverContext` and multiple drivers can run
/// independently (M1 doesn't exercise that directly, but nothing about
/// this store assumes there's only one).
library;

import 'config.dart';
import 'driver.dart';
import 'state.dart';

/// The small, fixed set of UI events the overlay/keyboard layer can raise
/// and `driver.dart` listens for. Mirrors the `allowedEvents` union in
/// `context.ts`. Most of these (everything but `overlayClick`) are wired up
/// once keyboard/click handling lands (M1's cutout only emits
/// `overlayClick`; the rest are M3/M4 scope) — the full enum is defined now
/// so `listen`/`emit` call sites don't need to change shape later.
enum DriverEvent {
  overlayClick,
  activeElementClick,
  escapePress,
  nextClick,
  prevClick,
  closeClick,
  arrowRightPress,
  arrowLeftPress,
}

/// Per-driver config + state + emitter, mirroring the `Context` object
/// `createContext()` returns in `context.ts`.
class DriverContext {
  DriverContext(DriverConfig config) : _config = config;

  DriverConfig _config;

  DriverConfig get config => _config;

  /// Replaces the config wholesale, mirroring `configure()` in
  /// `context.ts`: the previous config is discarded entirely rather than
  /// merged. This is safe (and matches JS's `{ ...defaults, ...config }`
  /// spread) precisely because `DriverConfig`'s own constructor already
  /// fills in every default field — a `DriverConfig` with only a couple of
  /// fields set is already "complete".
  void setConfig(DriverConfig config) => _config = config;

  /// Per-driver mutable state. Unlike [config], this is never replaced
  /// wholesale — call sites mutate its fields directly, mirroring
  /// `getState`/`setState` in `context.ts`.
  final DriverState state = DriverState();

  /// The owning `Driver`, set once by the `driver()` factory right after
  /// construction. Hooks receive it via [getHookOpts] so user code can
  /// call back into the driver (e.g. `opts.driver.destroy()`).
  Driver? driver;

  final Map<DriverEvent, void Function()> _listeners = {};

  /// Registers (replacing any previous registration) the callback for
  /// [event]. Mirrors `listen()` in `context.ts`, which is single-slot per
  /// event the same way.
  void listen(DriverEvent event, void Function() callback) =>
      _listeners[event] = callback;

  /// Invokes the callback registered for [event], if any.
  void emit(DriverEvent event) => _listeners[event]?.call();

  /// Clears every registered listener, called on `destroy()`.
  void resetEmitter() => _listeners.clear();

  /// Builds the [DriverHookOpts] passed to every lifecycle/click hook,
  /// mirroring `getHookOpts()` in `context.ts`. [stateOverride] lets a
  /// caller build opts against a snapshot rather than the live state (used
  /// by `onDestroyed`'s post-reset hook call, once `destroy()` needs that
  /// in M3).
  DriverHookOpts getHookOpts({DriverState? stateOverride}) {
    final activeState = stateOverride ?? state;
    return DriverHookOpts(
      config: _config,
      state: activeState,
      driver: driver!,
      index: activeState.activeIndex,
    );
  }
}
