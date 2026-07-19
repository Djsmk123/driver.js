/// The scenario model that every file under `lib/scenarios/` builds a
/// [ScenarioGroup] of, plus the [ScenarioContext] each scenario's `run`
/// closure receives to reach the stage, log events, and mount late content.
library;

import 'package:driverjs/driverjs.dart';
import 'package:flutter/widgets.dart';

import 'stage_page.dart';

/// One runnable demo scenario, triggerable from a sidebar list tile.
class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.run,
  });

  /// Stable, unique identifier (used as a list key).
  final String id;

  /// Short label shown in the sidebar.
  final String title;

  /// One-line explanation shown under the title / as a tooltip.
  final String description;

  /// Runs the scenario. Called with a fresh [ScenarioContext] every tap.
  final void Function(ScenarioContext ctx) run;
}

/// A named group of related [Scenario]s, rendered as a collapsible section
/// in the sidebar.
class ScenarioGroup {
  const ScenarioGroup({required this.title, required this.scenarios});

  final String title;
  final List<Scenario> scenarios;
}

/// Everything a scenario's `run` closure needs: a [BuildContext] to hand to
/// `driver()`/`hints()` as `config.context`, the stage's [StageKeys] so it
/// can reference the six demo cards, a log sink to make hook firings
/// visible, and a way to mount the late "waitForElement" target.
class ScenarioContext {
  const ScenarioContext({
    required this.context,
    required this.keys,
    required this.log,
    required this.mountLateElement,
    required this.unmountLateElement,
    required this.registerDriver,
    required this.registerHints,
  });

  final BuildContext context;
  final StageKeys keys;
  final void Function(String message) log;
  final VoidCallback mountLateElement;
  final VoidCallback unmountLateElement;

  /// Tracks [driver] as the "currently active" driver so the shell can
  /// defensively `destroy()` it before starting a different scenario (the
  /// plan's "safe to switch mid-tour" requirement). Scenarios that create a
  /// `Driver` should call this right after `driver(...)`.
  final void Function(Driver driver) registerDriver;

  /// Same as [registerDriver], for `Hints`.
  final void Function(Hints hints) registerHints;
}
