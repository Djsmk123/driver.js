/// Runtime toggle between a Material and a Cupertino demo shell — see
/// `main.dart`'s `DriverjsDemoRoot`, which rebuilds its whole widget tree
/// from the root whenever this value changes.
library;

import 'package:flutter/foundation.dart';

/// The two full UI designs the demo app can render as. Not a
/// `Theme.platform` flag — switching this swaps the entire widget tree
/// (`MaterialApp`/`Scaffold`/... vs `CupertinoApp`/`CupertinoPageScaffold`/...).
enum AppDesign { material, cupertino }

/// Holds the currently selected [AppDesign]. A single instance is created at
/// the root (`DriverjsDemoRoot`) and shared by both shells' design-switcher
/// controls.
class AppDesignController extends ValueNotifier<AppDesign> {
  AppDesignController([super.value = AppDesign.material]);
}

/// Shared breakpoint both shells use to decide between a persistent side
/// panel (wide) and a Drawer/pushed page (narrow). Kept in one place so the
/// two shells can't silently drift apart.
const double kWideBreakpoint = 900;
