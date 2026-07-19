/// `DriverPopover` (the popover configuration a step attaches) and
/// `DriverPopoverData` (the mutable, already-resolved model handed to
/// `onPopoverRender` and the default popover content widget), ported from
/// `popover.ts`'s `Popover`/`PopoverDOM`/`PopoverRenderOptions` types.
///
/// By the time [resolvePopoverData] runs, `step` is already the fully
/// button/text-resolved step `resolveTourStep`/`applyHighlightDefaults` in
/// `step.dart` produced (design decision #6) — what's left here is
/// resolving the button *tap handlers*, which stay unresolved until the
/// moment a button is actually pressed (design decision #9's "resolved at
/// tap time, not render time"), so a `setConfig`/navigation between render
/// and a later tap is still picked up.
library;

import 'package:flutter/widgets.dart';

import 'config.dart';
import 'context.dart';
import 'position.dart';
import 'step.dart';
import 'theme.dart';

/// Signature for `DriverConfig`/`DriverPopover`/`DriverTheme.popoverBuilder`
/// (design decision #8): fully replaces the default popover content
/// widget. The positioner and arrow painting in `popover_widget.dart` still
/// apply around whatever this returns — only the box's *contents* are
/// swapped out.
typedef DriverPopoverBuilder =
    Widget Function(DriverPopoverData data, DriverHookOpts opts);

/// Signature for `DriverConfig.onPopoverRender`/`DriverPopover.onPopoverRender`.
/// Mirrors `Popover["onPopoverRender"]`/`PopoverRenderOptions["onRender"]`
/// in `popover.ts`: called once the popover's data is resolved but before
/// it's laid out, so mutating [DriverPopoverData]'s fields here (texts,
/// button lists, `extraFooterChildren`) is reflected in what actually
/// renders.
typedef PopoverRenderHook =
    void Function(DriverPopoverData data, DriverHookOpts opts);

/// Per-step popover configuration. Mirrors `Popover` in `popover.ts`. Every
/// text slot has a plain-`String` version and a `Widget` twin
/// (`titleWidget`/`descriptionWidget`); when both are set on the resolved
/// [DriverPopoverData], the widget wins — see `popover_widget.dart`'s
/// default content widget.
class DriverPopover {
  const DriverPopover({
    this.title,
    this.description,
    this.titleWidget,
    this.descriptionWidget,
    this.side,
    this.align,
    this.showButtons,
    this.disableButtons,
    this.showProgress,
    this.progressText,
    this.nextBtnText,
    this.prevBtnText,
    this.doneBtnText,
    this.theme,
    this.popoverBuilder,
    this.onPopoverRender,
    this.onNextClick,
    this.onPrevClick,
    this.onCloseClick,
    this.onDoneClick,
  });

  final String? title;
  final String? description;

  /// Wins over [title] when both are set.
  final Widget? titleWidget;

  /// Wins over [description] when both are set.
  final Widget? descriptionWidget;

  /// Preferred side. `null` resolves to [Side.bottom], matching
  /// `Popover["side"]`'s JS default.
  final Side? side;

  /// Preferred cross-axis alignment. `null` resolves to
  /// [PopoverAlignment.start], matching JS's default.
  final PopoverAlignment? align;

  final List<DriverButton>? showButtons;
  final List<DriverButton>? disableButtons;
  final bool? showProgress;

  final String? progressText;
  final String? nextBtnText;
  final String? prevBtnText;
  final String? doneBtnText;

  /// Popover-only theme override, layered over `DriverConfig.theme`.
  final DriverTheme? theme;

  /// Fully replaces the default popover content for this popover only.
  /// Wins over `DriverTheme.popoverBuilder`/`DriverConfig.popoverBuilder`.
  final DriverPopoverBuilder? popoverBuilder;

  final PopoverRenderHook? onPopoverRender;
  final DriverHook? onNextClick;
  final DriverHook? onPrevClick;
  final DriverHook? onCloseClick;
  final DriverHook? onDoneClick;
}

/// The mutable model passed to [PopoverRenderHook]/[DriverPopoverBuilder]
/// before layout, and consumed by the default popover content widget.
/// Mirrors `PopoverDOM`/`PopoverRenderOptions` in `popover.ts`, minus the
/// DOM handles those types carry — there's no `HTMLElement` here, a widget
/// tree is built straight from these fields instead.
///
/// Mutating this from `onPopoverRender` (e.g. swapping `progressText`,
/// removing a button from [showButtons], appending to
/// [extraFooterChildren]) is exactly how the JS hook works too:
/// `renderPopover` calls `options.onRender?.(popover)` after the DOM nodes
/// exist but before `repositionPopover`, so user edits land before layout
/// there as well.
class DriverPopoverData {
  DriverPopoverData({
    this.title,
    this.titleWidget,
    this.description,
    this.descriptionWidget,
    List<DriverButton> showButtons = const [
      DriverButton.next,
      DriverButton.previous,
      DriverButton.close,
    ],
    List<DriverButton> disableButtons = const [],
    this.showProgress = false,
    this.progressText,
    this.nextBtnText = 'Next',
    this.prevBtnText = 'Previous',
    this.doneButton = false,
    this.onNextClick,
    this.onPrevClick,
    this.onCloseClick,
    List<Widget> extraFooterChildren = const [],
  }) : showButtons = List.of(showButtons),
       disableButtons = List.of(disableButtons),
       extraFooterChildren = List.of(extraFooterChildren);

  String? title;
  Widget? titleWidget;
  String? description;
  Widget? descriptionWidget;

  List<DriverButton> showButtons;
  List<DriverButton> disableButtons;
  bool showProgress;
  String? progressText;
  String nextBtnText;
  String prevBtnText;

  /// Styles the next button as the tour's done button (`doneButton` in
  /// `PopoverRenderOptions`). M2 never sets this itself — there's no "last
  /// reachable step" concept without tour navigation — but the field
  /// exists so `onPopoverRender` can flip it, and so M3's button
  /// resolution has somewhere to write it.
  bool doneButton;

  /// Resolved button click callbacks — already decided between step hooks,
  /// config hooks and a sensible default (see [resolvePopoverData]); the
  /// default content widget just wires these straight to `onPressed`.
  VoidCallback? onNextClick;
  VoidCallback? onPrevClick;
  VoidCallback? onCloseClick;

  /// Extra widgets appended to the footer's button group, after
  /// previous/next — the Flutter answer to `popover.ts`'s `onRender` hook
  /// letting callers append arbitrary DOM nodes into the wrapper.
  List<Widget> extraFooterChildren;
}

/// Whether the tour is currently on its last reachable step — with no tour
/// running (`activeIndex == null`, e.g. a bare `highlight()`) this is
/// always `false`. Backs [DriverPopoverData.doneButton], the widget-level
/// signal that the next button is acting as the done button (its text was
/// already swapped to `doneBtnText` upstream in `resolveTourStep`; this
/// flag exists purely for a builder/theme that wants to style it
/// differently).
bool _isLastReachableStep(DriverContext ctx) {
  final activeIndex = ctx.state.activeIndex;
  if (activeIndex == null) return false;
  final steps = ctx.config.steps ?? const <DriveStep>[];
  return findReachableIndex(steps, activeIndex + 1, 1, neverSkipStep) == null;
}

/// Resolves [step]/[popover] (already button/text-resolved by
/// `resolveTourStep`/`applyHighlightDefaults`) against [ctx] into a
/// [DriverPopoverData], including the tap-time button-handler resolution
/// this file's top-level doc comment describes: each `onXClick` closure
/// looks up `resolveNextHook`/`resolvePrevHook`/`resolveCloseHook` (step
/// popover → config → the tour's own navigation) *when pressed*, not when
/// this function runs, and falls all the way back to the live
/// `ctx.driver`'s `moveNext`/`movePrevious`/[DriverContext.requestUserClose]
/// for a step with no hook and no tour default at all (a bare
/// `highlight()`'s popover, say).
DriverPopoverData resolvePopoverData({
  required DriverContext ctx,
  required DriveStep step,
  required DriverPopover popover,
  required BuildContext? element,
}) {
  final config = ctx.config;

  return DriverPopoverData(
    title: popover.title,
    titleWidget: popover.titleWidget,
    description: popover.description,
    descriptionWidget: popover.descriptionWidget,
    showButtons: popover.showButtons ?? config.showButtons,
    disableButtons: popover.disableButtons ?? config.disableButtons,
    showProgress: popover.showProgress ?? config.showProgress,
    progressText: popover.progressText,
    nextBtnText: popover.nextBtnText ?? config.nextBtnText ?? 'Next',
    prevBtnText: popover.prevBtnText ?? config.prevBtnText ?? 'Previous',
    doneButton: _isLastReachableStep(ctx),
    onNextClick: () {
      final hook = resolveNextHook(ctx, step);
      if (hook != null) {
        hook(element, step, ctx.getHookOpts());
        return;
      }
      ctx.driver?.moveNext();
    },
    onPrevClick: () {
      final hook = resolvePrevHook(ctx, step);
      if (hook != null) {
        hook(element, step, ctx.getHookOpts());
        return;
      }
      ctx.driver?.movePrevious();
    },
    onCloseClick: () {
      final hook = resolveCloseHook(ctx, step);
      if (hook != null) {
        hook(element, step, ctx.getHookOpts());
        return;
      }
      ctx.requestUserClose?.call();
    },
  );
}
