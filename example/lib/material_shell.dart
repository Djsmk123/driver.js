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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'driverjs',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              group.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final scenario in group.scenarios)
            ListTile(
              dense: true,
              selected: scenario.id == _demo.activeScenarioId,
              title: Text(scenario.title),
              subtitle: Text(
                scenario.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                if (MediaQuery.sizeOf(context).width < kWideBreakpoint) {
                  Navigator.of(context).maybePop();
                }
                _runScenario(scenario);
              },
            ),
        ],
        const SizedBox(height: 24),
      ],
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
          padding: const EdgeInsets.all(8),
          child: LogPanel(
            controller: _demo.logController,
            initiallyExpanded: isWide,
          ),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: AppBar(title: const Text('driverjs demo')),
        body: Row(
          children: [
            SizedBox(
              width: 320,
              child: Material(elevation: 1, child: _buildSidebar(context)),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: stageAndLog),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('driverjs demo')),
      drawer: Drawer(child: _buildSidebar(context)),
      body: stageAndLog,
    );
  }
}
