/// A minimal, non-modal [OverlayRoute] used to mount the tour (`driver.dart`)
/// and hints (`hints.dart`) overlays onto the root [Navigator] instead of
/// inserting a raw [OverlayEntry] directly into the root [Overlay].
///
/// This exists because a raw [OverlayEntry] can never render *underneath* a
/// later-pushed route (e.g. a `showDialog` triggered from `onDestroyStarted`
/// for a confirm-on-exit pattern): `NavigatorState._flushHistoryUpdates`
/// calls `OverlayState.rearrange` on every route-stack change, and
/// `rearrange`'s contract is that any entry not passed to it — which a raw,
/// non-route `OverlayEntry` never is — is left on top of every rearranged
/// route entry, unconditionally, regardless of insertion order. Pushing this
/// route onto the [Navigator] instead makes the overlay content part of the
/// same route-stack bookkeeping (`Route.overlayEntries`, which is exactly
/// what `_allRouteOverlayEntries` collects), so a dialog pushed afterwards
/// naturally stacks above it, exactly like any other page content sitting
/// under a dialog.
///
/// Deliberately extends [OverlayRoute] rather than [PageRoute]/[ModalRoute]:
/// a [ModalRoute] unconditionally installs a full-screen [ModalBarrier] (even
/// with `barrierColor: null`, `buildModalBarrier` still returns a plain
/// `ModalBarrier`, not an empty widget), which absorbs every pointer event
/// itself — that would break hole-tap passthrough
/// (`disableActiveInteraction: false`/`advanceOnClick`) and the hints
/// package's translucent outside-tap catcher, both of which depend on
/// pointer events actually reaching the app content underneath. [OverlayRoute]
/// is the more primitive base `ModalRoute` builds on: it participates in the
/// exact same route-stack/`rearrange` bookkeeping without ever installing a
/// barrier of its own — the overlay content's own hit-testing (translucent
/// catchers, the stage cutout's hole) is the only thing that decides what
/// blocks a pointer event.
library;

import 'package:flutter/widgets.dart';

class DriverOverlayRoute extends OverlayRoute<void> {
  DriverOverlayRoute({required this.builder})
    : super(settings: const RouteSettings(name: 'driverjs-overlay'));

  final WidgetBuilder builder;

  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    return <OverlayEntry>[OverlayEntry(builder: builder)];
  }
}
