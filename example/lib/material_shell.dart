/// The Material design of the demo app — a `MaterialApp` plus the
/// responsive shell (320px sidebar + `VerticalDivider` + stage/log on wide
/// screens, a `Drawer` + stage/log on narrow). Formerly `DriverjsDemoApp`/
/// `DemoShell` in `main.dart`; now takes the shared [DemoController]/
/// [AppDesignController] from the root instead of owning its own state.
library;

import 'package:flutter/material.dart';

import 'app_design.dart';
import 'demo_controller.dart';
import 'log_panel.dart';
import 'scenario.dart';
import 'scenario_catalog.dart';
import 'stage_page.dart';

class MaterialDemoApp extends StatelessWidget {
  const MaterialDemoApp({super.key, required this.demo, required this.design});

  final DemoController demo;
  final AppDesignController design;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'driverjs demo',
      theme: ThemeData(colorSchemeSeed: kBrandColor, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: kBrandColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MaterialDemoShell(demo: demo, design: design),
    );
  }
}

/// The responsive shell: a sidebar of grouped scenarios (a [Drawer] on
/// narrow widths) plus the shared [StagePage] on the right/main content,
/// with a [LogPanel] beneath it.
class MaterialDemoShell extends StatefulWidget {
  const MaterialDemoShell({
    super.key,
    required this.demo,
    required this.design,
  });

  final DemoController demo;
  final AppDesignController design;

  @override
  State<MaterialDemoShell> createState() => _MaterialDemoShellState();
}

class _MaterialDemoShellState extends State<MaterialDemoShell> {
  DemoController get _demo => widget.demo;

  void _runScenario(Scenario scenario) {
    setState(() => _demo.runScenario(context, scenario));
  }

  Widget _buildSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerLow,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'driverjs',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: kSpacingMedium),
                SegmentedButton<AppDesign>(
                  segments: const [
                    ButtonSegment(
                      value: AppDesign.material,
                      label: Text('Material'),
                    ),
                    ButtonSegment(
                      value: AppDesign.cupertino,
                      label: Text('Cupertino'),
                    ),
                  ],
                  selected: {widget.design.value},
                  onSelectionChanged: (selection) {
                    _demo.teardownActive();
                    widget.design.value = selection.first;
                  },
                ),
              ],
            ),
          ),
          for (final group in scenarioCatalog) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                kSpacingMedium,
                16,
                kSpacingTiny,
              ),
              child: Text(
                group.title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final scenario in group.scenarios)
              _ScenarioListTile(
                title: scenario.title,
                subtitle: scenario.description,
                selected: scenario.id == _demo.activeScenarioId,
                onTap: () {
                  if (MediaQuery.sizeOf(context).width < kWideBreakpoint) {
                    Navigator.of(context).maybePop();
                  }
                  _runScenario(scenario);
                },
              ),
          ],
          const SizedBox(height: kSpacingLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    // Mobile-first base: a single scrollable-stage column with a Drawer for
    // the scenario list and a log panel that starts collapsed so it doesn't
    // dominate a phone-sized viewport. The wide two-pane layout below is an
    // enhancement layered on top when there's room, not the starting point.
    final stageAndLog = Column(
      children: [
        Expanded(
          child: StagePage(key: _demo.stagePageKey, keys: _demo.stageKeys),
        ),
        Padding(
          padding: const EdgeInsets.all(kSpacingSmall),
          child: LogPanel(
            controller: _demo.logController,
            initiallyExpanded: isWide,
          ),
        ),
      ],
    );

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: kSpacingSmall),
          const Text('driverjs demo'),
        ],
      ),
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            SizedBox(width: 320, child: _buildSidebar(context)),
            const VerticalDivider(width: 1),
            Expanded(child: stageAndLog),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: Drawer(child: _buildSidebar(context)),
      body: stageAndLog,
    );
  }
}

/// A scenario row in the sidebar. Selection is shown with a colored
/// left-border accent bar plus a tinted background (VS Code/Linear-style
/// list selection) rather than the barely-visible default `ListTile.selected`
/// tint, so the active scenario is obvious at a glance.
class _ScenarioListTile extends StatelessWidget {
  const _ScenarioListTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colorScheme.onPrimaryContainer : null,
          ),
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ),
    );
  }
}
