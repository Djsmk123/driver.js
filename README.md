# driverjs

A Flutter port of [driver.js](https://github.com/nilbuild/driver.js) — product
tours, single-element highlights, and pulsing hint beacons — with an API that
mirrors the driver.js JavaScript library as closely as Dart/Flutter allow.

## Installation

```yaml
dependencies:
  driverjs: ^0.1.0
```

```dart
import 'package:driverjs/driverjs.dart';
```

## Quick start

### Single-element highlight

Point `driver()` at a widget's `GlobalKey` and call `highlight()` to dim the
rest of the screen and cut out that one element:

```dart
final cardKey = GlobalKey();

final d = driver(DriverConfig(context: context));
d.highlight(
  DriveStep(
    element: cardKey,
    popover: const DriverPopover(
      title: 'Welcome',
      description: 'This is the card we want to draw attention to.',
    ),
  ),
);
```

`element` accepts a `GlobalKey`, a `BuildContext`, a zero-argument function
returning either (resolved lazily, handy when the target isn't known up
front), or `null` for a centered, element-less highlight. `context:` in
`DriverConfig` tells the driver which `Overlay` to mount into — see "How it
mounts" below.

### Multi-step tour

Give `DriverConfig` a list of `DriveStep`s and call `drive()` to start a
tour with Next/Previous/Close navigation and keyboard support built in:

```dart
final d = driver(
  DriverConfig(
    context: context,
    steps: [
      DriveStep(
        element: titleKey,
        popover: const DriverPopover(
          title: 'Step 1',
          description: 'This is the page title.',
        ),
      ),
      DriveStep(
        element: menuKey,
        popover: const DriverPopover(
          title: 'Step 2',
          description: 'Open the menu to see more options.',
        ),
      ),
      DriveStep(
        element: submitKey,
        popover: const DriverPopover(
          title: 'Step 3',
          description: 'Finally, hit submit when you are ready.',
        ),
      ),
    ],
  ),
);
d.drive(); // starts at step 0; pass an index to start elsewhere
```

Navigate programmatically with `d.moveNext()`, `d.movePrevious()`,
`d.moveTo(index)`, query state with `d.isFirstStep()`/`d.isLastStep()`/
`d.hasNextStep()`/etc., and tear the tour down with `d.destroy()`.

### Hints

`hints()` mounts one or more pulsing beacons that each open a small popover
on tap — independent of `driver()`/tours:

```dart
final h = hints(
  HintsConfig(
    context: context,
    hints: [
      DriverHint(
        element: searchKey,
        popover: const HintPopover(
          title: 'Search',
          description: 'Try searching for something.',
        ),
      ),
      DriverHint(
        element: profileKey,
        popover: const HintPopover(
          title: 'Your profile',
          description: 'Manage your account from here.',
        ),
      ),
    ],
  ),
);
h.show();
```

Beacons stay visible until `h.hide()`/`h.dismiss(id)`; `h.restore(id)` and
`h.restoreAll()` undo a dismissal.

## How it mounts

Both `driver()` and `hints()` mount their UI as a single root `OverlayEntry`
(via `Overlay.of(context, rootOverlay: true)`), not as a widget you place in
your own tree. That's what `DriverConfig.context`/`HintsConfig.context` is
for — if you don't pass one, the first step/hint whose `element` resolves to
a mounted `BuildContext` is used instead.

**Known mounting limitation:** because the overlay is inserted into the
*root* `Overlay` at the moment the tour/hints start, any route you `push`
*after* that point renders in a route's own overlay layer above the root
one — so a tour or hint popover started before a `Navigator.push` will end
up visually underneath the newly pushed route. Start (or refresh) a tour
after navigation settles if it needs to stay on top.

## API overview

Full reference lives in the generated dartdoc comments on each type; this is
just a map of what's there:

- **`driver()` / `Driver`** — creates the tour/highlight controller: `drive()`,
  `highlight()`, `moveNext()`/`movePrevious()`/`moveTo()`, state getters, and
  `destroy()`.
- **`DriveStep`** — one tour step (or a bare `highlight()` argument): target
  `element`, `popover`, and per-step overrides/hooks.
- **`DriverPopover`** — a step's popover content, buttons, and hooks.
- **`DriverConfig`** — top-level tour/highlight options: steps, animation,
  overlay color/opacity, button behavior, keyboard control, hooks, and more.
- **`hints()` / `Hints`** — creates the hints controller: `show()`, `hide()`,
  `open()`/`close()`, `dismiss()`/`restore()`/`restoreAll()`.
- **`DriverHint`** — one hint's target element, beacon, and popover.
- **`HintBeacon`** — a hint's pulsing beacon placement/style.
- **`HintPopover`** — a hint's popover content and single-button footer.
- **`DriverTheme`** — visual overrides for the overlay, stage, and popover
  shared by both `driver()` and `hints()`.

## Parity notes / known limitations

This port matches driver.js's behavior as closely as Flutter allows, with a
few deliberate or unavoidable differences:

- **Web keyboard focus.** Escape/arrow-key navigation requires the Flutter
  view itself to have keyboard focus. On web, clicking browser chrome (the
  address bar, devtools, another tab) can steal focus away from the page,
  which will make keyboard navigation stop responding until the view is
  clicked again.
- **Scroll locking.** driver.js's `allowScroll: false` works by injecting CSS
  into every scrollable ancestor of the target element to lock scrolling.
  Flutter has no equivalent hook into arbitrary `Scrollable`s, so this port
  does not lock scrolling when `allowScroll` is `false`; instead, the stage
  cutout stays glued to the target element and re-tracks it as the page
  scrolls.
- **Route stacking.** As noted above, routes pushed after a tour/hints
  overlay starts render above it, since the overlay is a root `OverlayEntry`
  inserted once at mount time.
- **Focus trap scope.** Keyboard focus cycling (Tab/Shift+Tab) while a tour
  popover is open only cycles the popover's own controls (Previous/Next/
  Close buttons); it does not also include the highlighted app element's
  focusable descendants the way a full DOM focus trap might.
- **Easing curve.** The stage-chase animation uses the exact same
  `easeInOutQuad` polynomial driver.js uses, not Flutter's built-in
  `Curves.easeInOutQuad`, so the motion timing matches the original
  pixel-for-pixel rather than approximately.
- **Null-guarded geometry reads.** A highlighted element's `GlobalKey.
  currentContext` can go `null` mid-animation (e.g. the widget is disposed
  while a transition is in flight). Every geometry read in this package is
  null-guarded and falls back to the last known rect rather than crashing or
  jumping.
- **Popover width clamping.** The popover's width is clamped to a minimum of
  250 and a maximum of `min(300, overlay width - 2 * arrow size)`, so it
  never overflows a narrow viewport.
- **Small-screen pinned fallback.** When there's no room to place the popover
  next to its target and it falls back to a pinned/bottom position, that
  fallback respects `MediaQuery.viewPadding.bottom` so it doesn't sit under a
  device's home indicator or system gesture area.

## Demo

The [`example/`](example) app is a Flutter web-first playground replicating
the driver.js docs/demo scenarios (47 scenarios across highlights, tours,
hints, and theming). Run it with:

```sh
cd example
flutter run -d chrome
```

## Packages

- `driverjs` (this package) — the library.
- [`example/`](example) — a Flutter web-first demo app replicating the
  driver.js docs and playground scenarios.
