import 'package:flutter/widgets.dart';

import 'app_design.dart';
import 'cupertino_shell.dart';
import 'demo_controller.dart';
import 'material_shell.dart';

void main() => runApp(DriverjsDemoRoot());

/// Root widget: owns the single [AppDesignController] and [DemoController]
/// shared by both shells, and swaps between [MaterialDemoApp] and
/// [CupertinoDemoApp] whenever [AppDesignController]'s value changes —
/// a genuine change of root widget (MaterialApp vs CupertinoApp), not just
/// a `Theme.platform` flag.
class DriverjsDemoRoot extends StatelessWidget {
  DriverjsDemoRoot({super.key});

  final _designController = AppDesignController();
  final _demoController = DemoController();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _designController,
    builder: (context, _) => switch (_designController.value) {
      AppDesign.material => MaterialDemoApp(
        demo: _demoController,
        design: _designController,
      ),
      AppDesign.cupertino => CupertinoDemoApp(
        demo: _demoController,
        design: _designController,
      ),
    },
  );
}
