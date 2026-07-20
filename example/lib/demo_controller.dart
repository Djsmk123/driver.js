/// Design-agnostic demo state/logic shared by both shells (Material and
/// Cupertino) — extracted from what used to be `_DemoShellState` so neither
/// shell owns its own copy of the active-scenario/teardown bookkeeping.
library;

import 'package:driverjs/driverjs.dart';
import 'package:flutter/widgets.dart';

import 'log_panel.dart';
import 'scenario.dart';
import 'stage_page.dart';

/// Owns everything about "which scenario is running" that is independent of
/// how the chrome around the stage is drawn: the stage's [StageKeys], the
/// [LogPanelController], a key onto the live [StagePageState] (so scenarios
/// can mount/unmount the late element), and the currently active
/// driver/hints instance (so switching scenarios — or switching
/// [AppDesign]s, which rebuilds the whole tree from a new root — never
/// leaves a stale overlay mounted).
class DemoController extends ChangeNotifier {
  final StageKeys stageKeys = StageKeys();
  final LogPanelController logController = LogPanelController();
  final GlobalKey<StagePageState> stagePageKey = GlobalKey<StagePageState>();

  Driver? _activeDriver;
  Hints? _activeHints;
  String? _activeScenarioId;

  String? get activeScenarioId => _activeScenarioId;

  /// Destroys/hides the active driver/hints (if any) without starting a new
  /// scenario. Called both at the start of [runScenario] (defensive teardown
  /// before switching scenarios mid-tour) and explicitly right before
  /// swapping [AppDesign] (the old widget tree — and any overlay tied to
  /// it — is about to be torn down wholesale).
  void teardownActive() {
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
  }

  void runScenario(BuildContext context, Scenario scenario) {
    teardownActive();

    _activeScenarioId = scenario.id;
    notifyListeners();

    final ctx = ScenarioContext(
      context: context,
      keys: stageKeys,
      log: logController.log,
      mountLateElement: () => stagePageKey.currentState?.mountLateElement(),
      unmountLateElement: () => stagePageKey.currentState?.unmountLateElement(),
      registerDriver: (d) => _activeDriver = d,
      registerHints: (h) => _activeHints = h,
    );

    logController.log('--- running "${scenario.title}" ---');
    scenario.run(ctx);
  }
}
