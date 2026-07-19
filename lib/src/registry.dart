/// A tiny cross-instance coordination point between tours (`driver.dart`)
/// and hints (`hints.dart`), so the two subsystems can cooperate without
/// referencing each other directly. Mirrors the DOM-class-marking trick
/// `hints.ts` uses instead (`document.body.classList.contains
/// ("driver-active")`, observed via a `MutationObserver`): a `Driver`
/// starting a tour has no Flutter analogue of "mark the document body", so
/// this package-level counter stands in for it.
///
/// Design decision #12 in the plan: "Tour coordination: `registry
/// .activeTourCount` — Driver init/destroy inc/dec; Hints listens and hides
/// while > 0."
library;

import 'package:flutter/foundation.dart';

/// Static, process-wide coordination state. Deliberately not per-instance —
/// every `Driver`/`Hints` created in the same isolate shares one counter, the
/// same way every driver.js tour on a page shares the one `document.body`
/// class the JS version toggles.
class DriverRegistry {
  DriverRegistry._();

  /// The number of currently-mounted tours (`Driver.drive()`/`highlight()`
  /// calls that have inserted their overlay `OverlayEntry` and not yet been
  /// `destroy()`ed). Incremented/decremented by `driver.dart`'s
  /// `_ensureMounted`/`_destroyInternal`; `hints.dart` only ever reads and
  /// listens, never writes, so two concurrent tours (or a tour plus a bare
  /// `highlight()`) net out correctly regardless of which one started or
  /// ended first — the count only reaches zero once every mounted driver has
  /// torn down.
  static final ValueNotifier<int> activeTourCount = ValueNotifier<int>(0);
}
