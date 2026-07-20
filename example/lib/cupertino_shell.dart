/// The Cupertino (iOS-style) design of the demo app — a genuine
/// `CupertinoApp`/`CupertinoPageScaffold`/`CupertinoNavigationBar` tree, not
/// a Material shell recolored. On narrow widths, the scenario list lives on
/// a pushed page (reached via the nav bar's leading button); on wide
/// widths, it's a persistent left panel next to the stage.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger;

import 'app_design.dart';
import 'cupertino_log_panel.dart';
import 'cupertino_stage_page.dart';
import 'demo_controller.dart';
import 'scenario.dart';
import 'scenario_catalog.dart';

class CupertinoDemoApp extends StatelessWidget {
  const CupertinoDemoApp({super.key, required this.demo, required this.design});

  final DemoController demo;
  final AppDesignController design;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'driverjs demo',
      theme: const CupertinoThemeData(primaryColor: kBrandColor),
      // Wrapped here (above the shell, not inside it) so `ScaffoldMessenger.
      // of(ctx.context)` — used by the `api` scenario group's snackbar demo,
      // a scenario file we can't modify — finds an ancestor even though the
      // rest of this tree is Cupertino-only. `MaterialApp` provides this
      // same wrap implicitly; `CupertinoApp` doesn't, so it's added by hand.
      home: ScaffoldMessenger(
        child: CupertinoDemoShell(demo: demo, design: design),
      ),
    );
  }
}

/// The design-switcher, pinned to the top of the scenario list panel in
/// both the wide side panel and the narrow pushed page.
class _DesignSwitcher extends StatelessWidget {
  const _DesignSwitcher({required this.demo, required this.design});

  final DemoController demo;
  final AppDesignController design;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kSpacingMedium),
      child: CupertinoSlidingSegmentedControl<AppDesign>(
        groupValue: design.value,
        children: const {
          AppDesign.material: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Material'),
          ),
          AppDesign.cupertino: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Cupertino'),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          demo.teardownActive();
          design.value = value;
        },
      ),
    );
  }
}

/// The scenario list — a `CupertinoListSection.insetGrouped` of the
/// catalog's groups/scenarios. Shared by the wide side panel and the narrow
/// pushed page. [onScenarioSelected] additionally pops the pushed page back
/// to the stage on narrow widths.
class _ScenarioList extends StatelessWidget {
  const _ScenarioList({required this.demo, required this.onScenarioSelected});

  final DemoController demo;
  final void Function(Scenario scenario) onScenarioSelected;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return ListView(
      children: [
        for (final group in scenarioCatalog)
          CupertinoListSection.insetGrouped(
            header: Text(group.title),
            children: [
              for (final scenario in group.scenarios)
                Builder(
                  builder: (context) {
                    final selected = scenario.id == demo.activeScenarioId;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: selected
                                ? primaryColor
                                : CupertinoColors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: CupertinoListTile(
                        backgroundColor: selected
                            ? primaryColor.withValues(alpha: 0.12)
                            : null,
                        title: Text(
                          scenario.title,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected ? primaryColor : null,
                          ),
                        ),
                        subtitle: Text(
                          scenario.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => onScenarioSelected(scenario),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// The pushed scenario-list page shown on narrow widths, reached via the
/// nav bar's leading button. [onScenarioSelected] is supplied by the shell
/// (bound to the shell's own, longer-lived `BuildContext`) rather than
/// running the scenario against this page's context directly — this page
/// is popped as part of selection, and its context shouldn't be relied on
/// once the pop is underway.
class _ScenarioListPage extends StatelessWidget {
  const _ScenarioListPage({
    required this.demo,
    required this.design,
    required this.onScenarioSelected,
  });

  final DemoController demo;
  final AppDesignController design;
  final void Function(Scenario scenario) onScenarioSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.secondarySystemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Scenarios')),
      child: SafeArea(
        child: Column(
          children: [
            _DesignSwitcher(demo: demo, design: design),
            Expanded(
              child: _ScenarioList(
                demo: demo,
                onScenarioSelected: (scenario) {
                  Navigator.of(context).pop();
                  onScenarioSelected(scenario);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CupertinoDemoShell extends StatefulWidget {
  const CupertinoDemoShell({
    super.key,
    required this.demo,
    required this.design,
  });

  final DemoController demo;
  final AppDesignController design;

  @override
  State<CupertinoDemoShell> createState() => _CupertinoDemoShellState();
}

class _CupertinoDemoShellState extends State<CupertinoDemoShell> {
  DemoController get _demo => widget.demo;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    final stageAndLog = Column(
      children: [
        Expanded(
          child: CupertinoStagePage(
            key: _demo.stagePageKey,
            keys: _demo.stageKeys,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(kSpacingSmall),
          child: CupertinoLogPanel(
            controller: _demo.logController,
            initiallyExpanded: isWide,
          ),
        ),
      ],
    );

    final navBarTitle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.compass,
          size: 20,
          color: CupertinoTheme.of(context).primaryColor,
        ),
        const SizedBox(width: kSpacingSmall),
        const Text('driverjs demo'),
      ],
    );

    if (isWide) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: navBarTitle),
        child: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: ColoredBox(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  child: Column(
                    children: [
                      _DesignSwitcher(demo: _demo, design: widget.design),
                      Expanded(
                        child: _ScenarioList(
                          demo: _demo,
                          onScenarioSelected: (scenario) => setState(
                            () => _demo.runScenario(context, scenario),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 0.5, color: CupertinoColors.separator),
              Expanded(child: stageAndLog),
            ],
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: navBarTitle,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (pushedContext) => _ScenarioListPage(
                  demo: _demo,
                  design: widget.design,
                  onScenarioSelected: (scenario) =>
                      setState(() => _demo.runScenario(context, scenario)),
                ),
              ),
            );
          },
          child: const Icon(CupertinoIcons.list_bullet),
        ),
      ),
      child: SafeArea(child: stageAndLog),
    );
  }
}
