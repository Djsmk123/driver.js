/// The scenario catalog, grouped for the sidebar/nav panel — shared by both
/// the Material and Cupertino shells so the list of demos can't drift
/// between them.
library;

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
