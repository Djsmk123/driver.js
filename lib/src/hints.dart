/// The public hints API (`hints()`/`Hints`/`HintsConfig`/`DriverHint`) and
/// its controller implementation, ported from `hints.ts`. Structurally this
/// mirrors `driver.dart`: its own root `OverlayEntry` (design decision #1,
/// adapted — see [Hints.show]'s doc comment), a [RefreshScheduler] +
/// [DriverMetricsObserver] pair for resize/frame-coalesced refresh (design
/// decision #5), and an imperative `GlobalKey<State>` bridge into the
/// mounted widget tree, the same division `_DriverImpl`/`DriverOverlay`
/// draws. What's different is scope: no stage-chase ticker (hint
/// repositioning always snaps — `hints.ts` never animates the cutout or
/// beacon position, only the pulse ring does, which is `hint_widgets.dart`'s
/// job), and up to *many* simultaneously-visible beacons instead of one
/// highlighted element.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'events.dart';
import 'hint_widgets.dart';
import 'overlay_widget.dart' show RenderOverlayCutout;
import 'popover.dart';
import 'popover_widget.dart';
import 'position.dart';
import 'registry.dart';
import 'theme.dart';
import 'utils.dart';

/// Signature shared by every hint lifecycle/click hook, mirroring
/// `HintHook` in `hints.ts`. Always called with a *resolved* element — a
/// hint whose element can't be found is skipped entirely by
/// [Hints.show]/`refresh` (see `hint_widgets.dart`'s anchor-point doc
/// comment), so unlike a tour's [DriverHook] there's no element-less case
/// hooks need to handle here.
typedef HintHook =
    void Function(BuildContext element, DriverHint hint, HintHookOpts opts);

/// Signature for `HintPopover.onPopoverRender`, mirroring `popover.dart`'s
/// [PopoverRenderHook] but scoped to a hint (an [HintHookOpts] instead of a
/// tour's [DriverHookOpts]) — reuses the same mutable [DriverPopoverData]
/// model the tour's popover mutates, so a caller who already knows that API
/// from tours doesn't have to learn a second one for hints.
typedef HintPopoverRenderHook =
    void Function(DriverPopoverData data, HintHookOpts opts);

/// Extra context handed to every [HintHook]/[HintPopoverRenderHook] call,
/// mirroring `{ config, hints }` in `hints.ts`'s `HintHook` type.
class HintHookOpts {
  const HintHookOpts({required this.config, required this.hints});

  /// The live config the [Hints] controller was built/last `setHints`'d
  /// with — lets a hook read sibling settings (e.g. `buttonText`) without
  /// needing its own closure over the original [HintsConfig].
  final HintsConfig config;

  /// The live [Hints] controller — lets a hook call back into it (e.g.
  /// `opts.hints.dismiss(...)` from a custom `onButtonClick`), the same way
  /// a tour hook's `DriverHookOpts.driver` does.
  final Hints hints;
}

/// One hint in a [HintsConfig.hints] list. Mirrors `DriverHint` in
/// `hints.ts`.
class DriverHint {
  const DriverHint({
    required this.element,
    this.id,
    this.beacon,
    this.popover,
    this.onOpen,
    this.onDismiss,
    this.data,
  });

  /// A [GlobalKey], a [BuildContext], or a zero-arg function returning
  /// either — resolved via `resolveTargetContext` in `utils.dart`, same as
  /// `DriveStep.element`. Unlike a tour step, `null` isn't accepted here:
  /// a hint with nothing to point at is meaningless (there's no
  /// element-less "centered" hint), so [HintsConfig] simply requires
  /// [element] be set for every entry.
  final Object element;

  /// Stable identity for `open`/`dismiss`/`restore`. `toString()`'d and
  /// compared against — `int`s and `String`s both work. Defaults to the
  /// hint's index in [HintsConfig.hints] when `null`, mirroring
  /// `hint.id ?? "${index}"` in `hints.ts`.
  final Object? id;

  /// Overrides `HintsConfig.beacon`.
  final HintBeacon? beacon;

  /// Per-hint popover copy/behavior (title, description, button text,
  /// render hook). `null` falls back to `HintsConfig.buttonText`/theme
  /// defaults with no title or description — mirrors `hint.popover` in
  /// `hints.ts` being optional.
  final HintPopover? popover;

  /// Fires once this hint's beacon becomes visible (mounted by [show] or a
  /// later [Hints.restore]) — mirrors `hint.onOpen` in `hints.ts`. Not
  /// called again on every [Hints.refresh]; only on the transition into
  /// visible.
  final HintHook? onOpen;

  /// Fires once this hint's beacon/popover is torn down, whether via
  /// [Hints.dismiss], [Hints.hide], or [Hints.setHints] replacing the list —
  /// mirrors `hint.onDismiss` in `hints.ts`.
  final HintHook? onDismiss;

  /// Arbitrary caller data, unread by this package — threaded through
  /// unchanged for hook implementations to stash their own bookkeeping on,
  /// mirroring `hint.data` in `hints.ts`.
  final Map<String, Object?>? data;
}

/// Top-level `hints()` configuration. Mirrors `HintsConfig` in `hints.ts`.
class HintsConfig {
  const HintsConfig({
    this.hints,
    this.beacon,
    this.buttonText,
    this.theme,
    this.popoverOffset = 10,
    this.overlay = false,
    this.overlayColor = const Color(0xFF000000),
    this.overlayOpacity = 0.7,
    this.context,
    this.onOpen,
    this.onDismiss,
    this.onButtonClick,
  });

  /// The hints to mount on [Hints.show]. `null`/`[]` means [Hints.show] is
  /// a no-op until a later [Hints.setHints] populates it — mirrors
  /// `config.hints` in `hints.ts` defaulting to `[]`.
  final List<DriverHint>? hints;

  /// Default beacon config for every hint; a hint's own [DriverHint.beacon]
  /// wins field-by-field... actually wholesale — see `hints.dart`'s
  /// `_beaconConfig`, which mirrors `hints.ts`'s `{ ...currentConfig.beacon,
  /// ...hint.beacon }` shallow-merge by picking the hint's `HintBeacon`
  /// outright when it's non-null, and this default otherwise (a `HintBeacon`
  /// is small enough that per-field merging isn't worth the ceremony a
  /// dedicated merge function would add).
  final HintBeacon? beacon;

  /// Falls back to `'Got it'` when neither this nor a hint's own
  /// `HintPopover.buttonText` is set.
  final String? buttonText;

  /// Config < step < hint level theme override for beacon/popover visuals —
  /// same [DriverTheme] object a tour's `DriverConfig.theme` uses, applied
  /// here to every hint that doesn't set its own via `HintPopover`.
  final DriverTheme? theme;

  /// Gap kept between the beacon (or, in overlay mode, the cutout) and the
  /// popover.
  final double popoverOffset;

  /// Dims the page with the active hint's element cut out, like a tour
  /// step, while its popover is open. See [Hints]'s class doc for the full
  /// behavior split.
  final bool overlay;

  /// Dim fill color when [overlay] is true. Defaults to `#000`, matching
  /// `DriverTheme.overlayColor`'s default (independent of [theme] since
  /// `hints.ts` exposes this as its own top-level config field, not nested
  /// under a theme object).
  final Color overlayColor;

  /// Opacity applied to [overlayColor] when [overlay] is true. Defaults to
  /// `0.7`, matching `DriverTheme.overlayOpacity`'s default.
  final double overlayOpacity;

  /// The [BuildContext] used to resolve the root [Overlay] to mount into
  /// (design decision #1). `null` resolves to the first hint whose element
  /// resolves to a mounted context.
  final BuildContext? context;

  /// Config-level fallback fired whenever any hint opens, in addition to
  /// that hint's own [DriverHint.onOpen] (both run, config-level first) —
  /// mirrors `config.onOpen` in `hints.ts`.
  final HintHook? onOpen;

  /// Config-level fallback fired whenever any hint dismisses, in addition
  /// to that hint's own [DriverHint.onDismiss] — mirrors `config.onDismiss`
  /// in `hints.ts`.
  final HintHook? onDismiss;

  /// Fired when a hint popover's default button ("Got it") is clicked,
  /// before the default dismiss-and-advance behavior runs — mirrors
  /// `config.onButtonClick` in `hints.ts`. There is no per-hint override for
  /// this one; it's config-level only.
  final HintHook? onButtonClick;
}

/// The public driver.js-mirroring hints API. See the plan's public API
/// sketch; every method is implemented as of M5.
abstract class Hints {
  /// Mounts the overlay entry (first call only) and (re)scans every
  /// configured hint for a resolvable, non-dismissed element, mounting a
  /// beacon for each one found — missing elements are silently skipped, no
  /// placeholder is drawn, and they're picked up automatically the next
  /// time [show] runs (not by [refresh], which only repositions/hides
  /// already-mounted beacons).
  void show();

  /// Unmounts the overlay entry entirely (closing any open popover first).
  /// Dismissed-hint bookkeeping survives — a later [show] still hides
  /// whatever was [dismiss]ed before this call.
  void hide();

  /// Opens [id]'s popover, closing whichever other hint's popover (if any)
  /// was open — only one is ever open at a time. A no-op for an
  /// unresolvable/dismissed/unknown id.
  void open(Object id);

  /// Closes whichever hint's popover is currently open. A no-op if none is.
  void close();

  /// Permanently hides [id]'s beacon (closing its popover first if it was
  /// the active one) until [restore]/[restoreAll] undoes it. Survives a
  /// [hide]→[show] cycle; cleared entirely by [setHints].
  void dismiss(Object id);

  /// Undoes a previous [dismiss] for [id], remounting its beacon
  /// immediately if [isVisible] and the element currently resolves.
  void restore(Object id);

  /// Undoes every previous [dismiss] at once.
  void restoreAll();

  /// Replaces the hint list wholesale and clears every dismissal — mirrors
  /// `setHints` in `hints.ts`, which resets `dismissed` unconditionally.
  void setHints(List<DriverHint> hints);

  /// The current hint list (`HintsConfig.hints`, `[]` if unset).
  List<DriverHint> getHints();

  /// The hint whose popover is currently open, if any.
  DriverHint? getActive();

  /// Whether [show] has been called without a matching [hide] since —
  /// independent of whether a tour is currently forcing the beacons
  /// invisible (design decision #12); that's a paint-only override, not a
  /// state change [isVisible] reports.
  bool isVisible();

  /// Frame-coalesced re-sync: repositions every mounted beacon and, if a
  /// popover is open, re-anchors it — the hints equivalent of
  /// `Driver.refresh()`. Also where scrolled-out-of-view beacons get hidden
  /// (closing their popover if it was the active one); see the plan's
  /// visibility-intersection requirement.
  void refresh();
}

/// Creates a [Hints] controller, mirroring the `hints(config)` factory in
/// `hints.ts`.
Hints hints([HintsConfig config = const HintsConfig()]) => _HintsImpl(config);

/// Render-ready info for one currently-visible beacon, computed fresh every
/// [_HintsImpl.refresh] and handed to [_HintsOverlayState.updateBeacons].
class _BeaconRenderInfo {
  const _BeaconRenderInfo({
    required this.id,
    required this.point,
    required this.style,
    required this.animate,
    required this.onTap,
  });

  final String id;
  final Offset point;
  final HintBeaconStyle style;
  final bool? animate;
  final VoidCallback onTap;
}

class _HintsImpl implements Hints {
  _HintsImpl(this._config);

  HintsConfig _config;

  /// Ids permanently hidden until `restore`/`restoreAll` — survives
  /// `hide()`/`show()`, cleared only by `setHints`.
  final Set<String> _dismissed = {};

  /// Ids currently mounted (resolvable + not dismissed as of the last
  /// `show()`/`setHints`/`restore(All)` scan) — `refresh()` reads this set
  /// but never adds to it, mirroring `hints.ts`'s `mounted` array only
  /// growing inside `mountHint`/`mountHints`.
  final Set<String> _mountedIds = {};

  bool _isVisible = false;
  String? _activeId;

  OverlayEntry? _entry;
  final GlobalKey<_HintsOverlayState> _overlayKey =
      GlobalKey<_HintsOverlayState>();
  RefreshScheduler? _refreshScheduler;
  DriverMetricsObserver? _metricsObserver;
  VoidCallback? _registryListener;

  String _hintId(DriverHint hint, int index) => hint.id?.toString() ?? '$index';

  List<DriverHint> get _hints => _config.hints ?? const <DriverHint>[];

  int? _indexOf(String id) {
    final list = _hints;
    for (var i = 0; i < list.length; i++) {
      if (_hintId(list[i], i) == id) return i;
    }
    return null;
  }

  DriverHint? _hintById(String id) {
    final index = _indexOf(id);
    return index == null ? null : _hints[index];
  }

  HintBeacon _beaconConfig(DriverHint hint) =>
      hint.beacon ?? _config.beacon ?? const HintBeacon();

  HintHookOpts get _hookOpts => HintHookOpts(config: _config, hints: this);

  @override
  void show() {
    if (!_isVisible) {
      final mountContext = _resolveMountContext();
      if (mountContext == null) {
        throw FlutterError.fromParts([
          ErrorSummary(
            'driverjs: could not resolve a BuildContext to mount the hints '
            'overlay.',
          ),
          ErrorDescription(
            'Pass `context:` in HintsConfig, or make sure at least one '
            'hint\'s `element` resolves to a mounted widget before calling '
            'show().',
          ),
        ]);
      }
      _isVisible = true;
      _ensureMounted(mountContext);
      _armRegistryListener();
    }

    // Re-scans every call — picks up hints whose elements have appeared
    // since the last show(), mirrors `mountHints()` being unconditional in
    // `show()` in hints.ts.
    _mountHints();
    _scheduleRefresh();
  }

  BuildContext? _resolveMountContext() {
    final configContext = _config.context;
    if (configContext != null && configContext.mounted) return configContext;
    for (final hint in _hints) {
      final ctx = resolveTargetContext(hint.element);
      if (ctx != null) return ctx;
    }
    return null;
  }

  void _ensureMounted(BuildContext mountContext) {
    if (_entry != null) return;

    final overlayState = Overlay.of(mountContext, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: _HintsOverlay(
            key: _overlayKey,
            overlay: _config.overlay,
            overlayColor: _config.overlayColor,
            overlayOpacity: _config.overlayOpacity,
            onOutsideTap: close,
            onEscape: _handleEscape,
          ),
        );
      },
    );
    overlayState.insert(_entry!);

    _refreshScheduler = RefreshScheduler(refresh);
    _metricsObserver = DriverMetricsObserver(_refreshScheduler!);
    WidgetsBinding.instance.addObserver(_metricsObserver!);
  }

  /// Design decision #12: while `DriverRegistry.activeTourCount` is above
  /// zero, the mounted overlay hides itself (without losing `isVisible`/
  /// dismissed/active state) and restores once it drops back to zero.
  void _armRegistryListener() {
    if (_registryListener != null) return;
    _registryListener = () {
      _overlayKey.currentState?.setHiddenByTour(
        DriverRegistry.activeTourCount.value > 0,
      );
    };
    DriverRegistry.activeTourCount.addListener(_registryListener!);
    // Apply whatever the count already is right now — a tour could already
    // be running when `show()` is called.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _overlayKey.currentState?.setHiddenByTour(
        DriverRegistry.activeTourCount.value > 0,
      );
    });
  }

  @override
  void hide() {
    if (!_isVisible) return;
    _isVisible = false;

    close();
    _mountedIds.clear();

    if (_registryListener != null) {
      DriverRegistry.activeTourCount.removeListener(_registryListener!);
      _registryListener = null;
    }
    if (_metricsObserver != null) {
      WidgetsBinding.instance.removeObserver(_metricsObserver!);
      _metricsObserver = null;
    }
    _refreshScheduler?.dispose();
    _refreshScheduler = null;

    _entry?.remove();
    _entry = null;
  }

  void _mountHints() {
    final list = _hints;
    for (var i = 0; i < list.length; i++) {
      final id = _hintId(list[i], i);
      if (_dismissed.contains(id) || _mountedIds.contains(id)) continue;
      if (resolveTargetContext(list[i].element) != null) {
        _mountedIds.add(id);
      }
    }
  }

  void _scheduleRefresh() {
    SchedulerBinding.instance.addPostFrameCallback((_) => refresh());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void refresh() {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    final overlayBox = overlay.overlayBox;

    final beacons = <_BeaconRenderInfo>[];
    String? hideActiveBecauseInvisible;

    for (final id in _mountedIds.toList()) {
      final hint = _hintById(id);
      if (hint == null) {
        _mountedIds.remove(id);
        continue;
      }

      final elementContext = resolveTargetContext(hint.element);
      final rect = elementContext == null
          ? null
          : rectOfContext(elementContext, overlayBox);
      final visible =
          elementContext != null &&
          rect != null &&
          _isRectVisible(rect, elementContext, overlayBox);

      if (!visible) {
        if (_activeId == id) hideActiveBecauseInvisible = id;
        continue;
      }

      final beaconCfg = _beaconConfig(hint);
      final style = beaconCfg.style ?? const HintBeaconStyle();
      final side = beaconCfg.side ?? Side.top;
      final align = beaconCfg.align ?? PopoverAlignment.end;
      final point = resolveBeaconAnchorPoint(
        element: rect,
        side: side,
        align: align,
        offsetX: beaconCfg.offsetX,
        offsetY: beaconCfg.offsetY,
      );

      // Overlay mode: the spotlight does the pointing, so the beacon steps
      // aside while its own popover is open (mirrors `entry.beacon.style
      // .display = "none"` in `open()`/`hints.ts`).
      final hideBeacon = _config.overlay && _activeId == id;
      if (!hideBeacon) {
        beacons.add(
          _BeaconRenderInfo(
            id: id,
            point: point,
            style: style,
            animate: beaconCfg.animate,
            onTap: () => _toggle(id),
          ),
        );
      }
    }

    overlay.updateBeacons(beacons);

    if (hideActiveBecauseInvisible != null) {
      // The beacon is gone from the screen — close its popover rather than
      // leave it anchored to nothing (mirrors the `IntersectionObserver`
      // callback in `hints.ts` calling `close()`).
      close();
      return;
    }

    final activeId = _activeId;
    if (activeId != null) {
      _renderPopoverFor(activeId, overlayBox);
    }
  }

  /// Whether [rect] (already in overlay-local coordinates) is visible: not
  /// fully outside the overlay bounds, and not fully clipped by any
  /// ancestor [Scrollable]'s viewport. Mirrors the combination of "outside
  /// the overlay" and driver.js's `IntersectionObserver`-driven
  /// out-of-viewport hiding.
  bool _isRectVisible(
    Rect rect,
    BuildContext elementContext,
    RenderBox overlayBox,
  ) {
    var visible = rect.intersect(Offset.zero & overlayBox.size);
    if (visible.width <= 0 || visible.height <= 0) return false;

    elementContext.visitAncestorElements((ancestor) {
      final state = ancestor is StatefulElement ? ancestor.state : null;
      if (state is ScrollableState) {
        final renderObject = state.context.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.attached &&
            renderObject.hasSize) {
          final topLeft = renderObject.localToGlobal(
            Offset.zero,
            ancestor: overlayBox,
          );
          visible = visible.intersect(topLeft & renderObject.size);
        }
      }
      return visible.width > 0 && visible.height > 0;
    });

    return visible.width > 0 && visible.height > 0;
  }

  void _renderPopoverFor(String id, RenderBox overlayBox) {
    final hint = _hintById(id);
    if (hint == null) {
      close();
      return;
    }
    final elementContext = resolveTargetContext(hint.element);
    final elementRect = elementContext == null
        ? null
        : rectOfContext(elementContext, overlayBox);
    if (elementContext == null || elementRect == null) {
      close();
      return;
    }

    final beaconCfg = _beaconConfig(hint);
    final style = beaconCfg.style ?? const HintBeaconStyle();
    final side = beaconCfg.side ?? Side.top;
    final align = beaconCfg.align ?? PopoverAlignment.end;
    final beaconPoint = resolveBeaconAnchorPoint(
      element: elementRect,
      side: side,
      align: align,
      offsetX: beaconCfg.offsetX,
      offsetY: beaconCfg.offsetY,
    );

    final popoverCfg = hint.popover ?? const HintPopover();
    final position = resolveHintPopoverPosition(
      popover: popoverCfg,
      elementRect: elementRect,
      beaconPoint: beaconPoint,
      beaconSize: style.size,
      popoverOffset: _config.popoverOffset,
      overlay: _config.overlay,
    );

    final buttonText = popoverCfg.buttonText ?? _config.buttonText ?? 'Got it';
    final hookOpts = _hookOpts;

    final data = DriverPopoverData(
      title: popoverCfg.title,
      titleWidget: popoverCfg.titleWidget,
      description: popoverCfg.description,
      descriptionWidget: popoverCfg.descriptionWidget,
      showButtons: popoverCfg.showButton ? const [DriverButton.next] : const [],
      disableButtons: const [],
      showProgress: false,
      progressText: '',
      nextBtnText: buttonText,
      prevBtnText: '',
      onNextClick: () {
        final handler = popoverCfg.onButtonClick ?? _config.onButtonClick;
        if (handler != null) {
          handler(elementContext, hint, hookOpts);
          return;
        }
        dismiss(id);
      },
    );

    popoverCfg.onPopoverRender?.call(data, hookOpts);

    final theme = _config.theme ?? const DriverTheme();
    final content = DriverPopoverContent(data: data, theme: theme);

    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    overlay.showPopover(
      content: content,
      anchor: position.anchor,
      side: position.side,
      align: position.align,
      offset: position.offset,
      padding: position.padding,
      arrowSize: kHintArrowSize,
      arrowColor: theme.popoverBackgroundColor,
      cutoutRect: _config.overlay ? elementRect : null,
      cutoutColor: _config.overlayColor,
      cutoutOpacity: _config.overlayOpacity,
    );
  }

  void _toggle(String id) {
    if (_activeId == id) {
      close();
    } else {
      open(id);
    }
  }

  @override
  void open(Object id) {
    final strId = id.toString();
    if (!_mountedIds.contains(strId)) return;
    final hint = _hintById(strId);
    if (hint == null) return;
    final elementContext = resolveTargetContext(hint.element);
    if (elementContext == null) return;

    // Only one hint is open at a time; opening another swaps it out.
    close();

    _activeId = strId;

    final onOpen = hint.onOpen ?? _config.onOpen;
    onOpen?.call(elementContext, hint, _hookOpts);

    refresh();
  }

  @override
  void close() {
    if (_activeId == null) return;
    _activeId = null;
    _overlayKey.currentState?.hidePopover();
    // Recompute beacons (an overlay-mode close brings the just-closed
    // hint's own beacon back) and repaint without a popover anchored.
    refresh();
  }

  @override
  void dismiss(Object id) {
    final strId = id.toString();
    final hint = _hintById(strId);
    if (hint == null) return;

    if (_activeId == strId) close();

    _dismissed.add(strId);
    _mountedIds.remove(strId);

    final elementContext = resolveTargetContext(hint.element);
    if (elementContext != null) {
      final onDismiss = hint.onDismiss ?? _config.onDismiss;
      onDismiss?.call(elementContext, hint, _hookOpts);
    }

    refresh();
  }

  @override
  void restore(Object id) {
    final strId = id.toString();
    if (!_dismissed.remove(strId)) return;
    if (!_isVisible || _mountedIds.contains(strId)) return;

    final hint = _hintById(strId);
    if (hint == null) return;
    if (resolveTargetContext(hint.element) != null) {
      _mountedIds.add(strId);
      refresh();
    }
  }

  @override
  void restoreAll() {
    _dismissed.clear();
    if (_isVisible) {
      _mountHints();
      refresh();
    }
  }

  @override
  void setHints(List<DriverHint> hints) {
    _config = HintsConfig(
      hints: hints,
      beacon: _config.beacon,
      buttonText: _config.buttonText,
      theme: _config.theme,
      popoverOffset: _config.popoverOffset,
      overlay: _config.overlay,
      overlayColor: _config.overlayColor,
      overlayOpacity: _config.overlayOpacity,
      context: _config.context,
      onOpen: _config.onOpen,
      onDismiss: _config.onDismiss,
      onButtonClick: _config.onButtonClick,
    );
    _dismissed.clear();

    if (!_isVisible) return;

    close();
    _mountedIds.clear();
    _mountHints();
    refresh();
  }

  @override
  List<DriverHint> getHints() => _hints;

  @override
  DriverHint? getActive() {
    final id = _activeId;
    return id != null ? _hintById(id) : null;
  }

  @override
  bool isVisible() => _isVisible;

  void _handleEscape() {
    final id = _activeId;
    if (id == null) return;
    close();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _overlayKey.currentState?.focusBeacon(id),
    );
  }
}

/// The widget mounted into the hints' own root `OverlayEntry`. Owns the
/// mounted beacons/popover/cutout as plain state, updated imperatively by
/// [_HintsImpl] via this state's `GlobalKey` — the same
/// controller-drives-a-`State` split `driver.dart`/`overlay_widget.dart`
/// use for the tour.
class _HintsOverlay extends StatefulWidget {
  const _HintsOverlay({
    super.key,
    required this.overlay,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.onOutsideTap,
    required this.onEscape,
  });

  /// `HintsConfig.overlay` at construction time — whether outside-tap
  /// detection (non-overlay mode) or the dim-with-cutout layer (overlay
  /// mode) is used; the two are mutually exclusive, see [Hints]'s class doc.
  final bool overlay;
  final Color overlayColor;
  final double overlayOpacity;

  /// Fired by the non-overlay-mode outside-tap catcher and by the
  /// overlay-mode dim tap — both close whatever popover is open.
  final VoidCallback onOutsideTap;
  final VoidCallback onEscape;

  @override
  State<_HintsOverlay> createState() => _HintsOverlayState();
}

class _HintsOverlayState extends State<_HintsOverlay> {
  List<_BeaconRenderInfo> _beacons = const [];
  final Map<String, FocusNode> _beaconFocusNodes = {};

  Widget? _popoverContent;
  Rect _popoverAnchor = Rect.zero;
  Side _popoverSide = Side.bottom;
  PopoverAlignment _popoverAlign = PopoverAlignment.start;
  double _popoverOffset = 10;
  double _popoverPadding = 0;
  double _popoverArrowSize = kHintArrowSize;
  Color _popoverArrowColor = const Color(0xFFFFFFFF);

  Rect? _cutoutRect;
  Color _cutoutColor = const Color(0xFF000000);
  double _cutoutOpacity = 0.7;

  bool _hiddenByTour = false;

  final FocusScopeNode _popoverFocusScope = FocusScopeNode(
    debugLabel: 'driverjs-hints-popover',
  );

  RenderBox get overlayBox => context.findRenderObject()! as RenderBox;

  void setHiddenByTour(bool value) {
    if (_hiddenByTour == value) return;
    setState(() => _hiddenByTour = value);
  }

  void updateBeacons(List<_BeaconRenderInfo> beacons) {
    final ids = beacons.map((b) => b.id).toSet();
    _beaconFocusNodes.removeWhere((id, node) {
      if (ids.contains(id)) return false;
      node.dispose();
      return true;
    });
    for (final id in ids) {
      _beaconFocusNodes.putIfAbsent(
        id,
        () => FocusNode(debugLabel: 'driverjs-hint-beacon-$id'),
      );
    }
    setState(() => _beacons = beacons);
  }

  void focusBeacon(String id) {
    final node = _beaconFocusNodes[id];
    if (node != null && node.canRequestFocus) node.requestFocus();
  }

  void showPopover({
    required Widget content,
    required Rect anchor,
    required Side side,
    required PopoverAlignment align,
    required double offset,
    required double padding,
    required double arrowSize,
    required Color arrowColor,
    required Rect? cutoutRect,
    required Color cutoutColor,
    required double cutoutOpacity,
  }) {
    setState(() {
      _popoverContent = content;
      _popoverAnchor = anchor;
      _popoverSide = side;
      _popoverAlign = align;
      _popoverOffset = offset;
      _popoverPadding = padding;
      _popoverArrowSize = arrowSize;
      _popoverArrowColor = arrowColor;
      _cutoutRect = cutoutRect;
      _cutoutColor = cutoutColor;
      _cutoutOpacity = cutoutOpacity;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _popoverFocusScope.nextFocus();
    });
  }

  void hidePopover() {
    if (_popoverContent == null && _cutoutRect == null) return;
    setState(() {
      _popoverContent = null;
      _cutoutRect = null;
    });
  }

  @override
  void dispose() {
    for (final node in _beaconFocusNodes.values) {
      node.dispose();
    }
    _popoverFocusScope.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onEscape();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final popoverContent = _popoverContent;
    final cutoutRect = _cutoutRect;

    final content = Stack(
      children: [
        // Non-overlay mode: a translucent, non-consuming outside-tap
        // catcher that never blocks the page underneath — see
        // [_OutsideTapCatcher]'s doc comment.
        if (!widget.overlay) _OutsideTapCatcher(onTap: widget.onOutsideTap),
        // Overlay mode: only present while a popover is open (mirrors
        // `showOverlay`/`removeOverlay` being tied to `open()`/`close()`
        // in hints.ts) — dims the page with the active hint's element cut
        // out; tapping the dim closes it.
        if (widget.overlay && cutoutRect != null)
          _HintCutoutWidget(
            stageRect: cutoutRect,
            overlayColor: _cutoutColor,
            overlayOpacity: _cutoutOpacity,
            onOverlayTap: widget.onOutsideTap,
          ),
        for (final beacon in _beacons)
          Positioned(
            left: beacon.point.dx - beacon.style.size / 2,
            top: beacon.point.dy - beacon.style.size / 2,
            width: beacon.style.size,
            height: beacon.style.size,
            child: HintBeaconWidget(
              style: beacon.style,
              animate: beacon.animate,
              onTap: beacon.onTap,
              focusNode: _beaconFocusNodes[beacon.id],
            ),
          ),
        if (popoverContent != null)
          FocusTraversalGroup(
            child: FocusScope(
              node: _popoverFocusScope,
              child: PopoverPositioner(
                element: _popoverAnchor,
                side: _popoverSide,
                align: _popoverAlign,
                offset: _popoverOffset,
                padding: _popoverPadding,
                centered: false,
                arrowColor: _popoverArrowColor,
                arrowSize: _popoverArrowSize,
                child: popoverContent,
              ),
            ),
          ),
      ],
    );

    return FocusScope(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      // Hidden (not unmounted) while a tour is active (design decision
      // #12): `maintainState` keeps beacon focus nodes / animation
      // controllers alive so re-showing after the tour ends doesn't lose
      // any transient UI state, matching "hides itself ... restoring
      // visibility when it drops back to 0".
      child: Visibility(
        visible: !_hiddenByTour,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: false,
        child: content,
      ),
    );
  }
}

/// A translucent, full-screen layer that observes taps without ever
/// consuming the gesture arena — [Listener] (unlike [GestureDetector])
/// doesn't compete for a gesture recognition win, so the app underneath
/// (and any beacon/popover painted on top of this in the same [Stack])
/// keeps receiving every pointer event untouched. This is what makes
/// non-overlay-mode hints "never block the page" (design decision #4,
/// adapted for hints): the only thing this widget does is notice a tap
/// that nothing else claimed and ask [onTap] to close the open popover.
class _OutsideTapCatcher extends StatefulWidget {
  const _OutsideTapCatcher({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_OutsideTapCatcher> createState() => _OutsideTapCatcherState();
}

class _OutsideTapCatcherState extends State<_OutsideTapCatcher> {
  Offset? _downPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _downPosition = event.position,
      onPointerUp: (event) {
        final down = _downPosition;
        _downPosition = null;
        if (down != null && (event.position - down).distance <= kTouchSlop) {
          widget.onTap();
        }
      },
      onPointerCancel: (_) => _downPosition = null,
      child: const SizedBox.expand(),
    );
  }
}

/// Thin wrapper around [RenderOverlayCutout] (reused verbatim from
/// `overlay_widget.dart`, per the plan's instruction to call into
/// `stage.dart`'s cutout machinery rather than reimplement it) for the
/// overlay-mode dim: `disableActiveInteraction: false` keeps the cutout
/// hole translucent (the highlighted element itself stays interactive,
/// same as a tour's stage), and [onHoleTap] is unused — hints have no
/// `advanceOnClick` equivalent.
class _HintCutoutWidget extends LeafRenderObjectWidget {
  const _HintCutoutWidget({
    required this.stageRect,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.onOverlayTap,
  });

  final Rect stageRect;
  final Color overlayColor;
  final double overlayOpacity;
  final VoidCallback onOverlayTap;

  @override
  RenderOverlayCutout createRenderObject(BuildContext context) {
    return RenderOverlayCutout(
      stageRect: stageRect,
      overlayColor: overlayColor,
      overlayOpacity: overlayOpacity,
      stagePadding: kHintOverlayPadding,
      stageRadius: kHintOverlayRadius,
      disableActiveInteraction: false,
      onOverlayTap: onOverlayTap,
      onHoleTap: () {},
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOverlayCutout renderObject,
  ) {
    renderObject
      ..stageRect = stageRect
      ..overlayColor = overlayColor
      ..overlayOpacity = overlayOpacity
      ..stagePadding = kHintOverlayPadding
      ..stageRadius = kHintOverlayRadius
      ..disableActiveInteraction = false
      ..onOverlayTap = onOverlayTap;
  }
}
