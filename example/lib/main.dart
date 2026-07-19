import 'package:driverjs/driverjs.dart';
import 'package:flutter/material.dart';

import 'log_panel.dart';
import 'scenario.dart';
import 'scenarios/advance_wait.dart';
import 'scenarios/api.dart';
import 'scenarios/arrow.dart';
import 'scenarios/duration.dart';
import 'scenarios/highlight.dart';
import 'scenarios/hints.dart' as hint_scenarios;
import 'scenarios/instances.dart';
import 'scenarios/popover.dart';
import 'scenarios/scroll.dart';
import 'scenarios/skip_missing.dart';
import 'scenarios/tour.dart';
import 'stage_page.dart';

void main() {
  runApp(const DriverjsDemoApp());
}

/// The scenario catalog, grouped for the sidebar — see the plan's "Demo app"
/// section for the full list this mirrors.
final List<ScenarioGroup> scenarioCatalog = [
  highlightGroup,
  popoverGroup,
  arrowGroup,
  tourGroup,
  advanceWaitGroup,
  skipMissingGroup,
  instancesGroup,
  durationGroup,
  scrollGroup,
  hint_scenarios.hintsGroup,
  apiGroup,
];

class DriverjsDemoApp extends StatelessWidget {
  const DriverjsDemoApp({super.key});

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
      home: const DemoShell(),
    );
  }
}

/// The responsive shell: a sidebar of grouped scenarios (a [Drawer] on
/// narrow widths) plus the shared [StagePage] on the right/main content,
/// with a [LogPanel] beneath it.
class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  static const double _wideBreakpoint = 900;

  final StageKeys _stageKeys = StageKeys();
  final LogPanelController _logController = LogPanelController();
  final GlobalKey<StagePageState> _stagePageKey = GlobalKey<StagePageState>();

  Driver? _activeDriver;
  Hints? _activeHints;
  String? _activeScenarioId;

  void _runScenario(Scenario scenario) {
    // Defensive teardown (plan requirement: "safe to switch to a different
    // scenario mid-tour") — never leave a previous scenario's overlay
    // mounted underneath the next one's.
    final previousDriver = _activeDriver;
    if (previousDriver != null && previousDriver.isActive()) {
      previousDriver.destroy();
    }
    final previousHints = _activeHints;
    if (previousHints != null && previousHints.isVisible()) {
      previousHints.hide();
    }
    _activeDriver = null;
    _activeHints = null;

    setState(() => _activeScenarioId = scenario.id);

    final ctx = ScenarioContext(
      context: context,
      keys: _stageKeys,
      log: _logController.log,
      mountLateElement: () => _stagePageKey.currentState?.mountLateElement(),
      unmountLateElement: () =>
          _stagePageKey.currentState?.unmountLateElement(),
      registerDriver: (d) => _activeDriver = d,
      registerHints: (h) => _activeHints = h,
    );

    _logController.log('--- running "${scenario.title}" ---');
    scenario.run(ctx);
  }

  Widget _buildSidebar(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              'driverjs',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
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
              selected: scenario.id == _activeScenarioId,
              title: Text(scenario.title),
              subtitle: Text(
                scenario.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                if (MediaQuery.sizeOf(context).width < _wideBreakpoint) {
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
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final stageAndLog = Column(
      children: [
        Expanded(
          child: StagePage(key: _stagePageKey, keys: _stageKeys),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: LogPanel(controller: _logController),
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
