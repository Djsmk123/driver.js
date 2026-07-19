/// A collapsible panel that renders a running log of hook/event firings.
/// Scenario code calls the sink this exposes (via [LogPanelController]) from
/// its `DriverConfig`/`DriveStep`/`HintsConfig` hooks, so a human watching
/// the demo can see hooks actually fire, not just take it on faith.
library;

import 'package:flutter/material.dart';

/// Owns the log entries and notifies [LogPanel] to rebuild. Held by
/// whichever widget mounts the stage (usually `main.dart`'s shell) and
/// threaded into every [ScenarioContext] as its `log` sink.
class LogPanelController extends ChangeNotifier {
  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last;
    _entries.insert(0, '[$timestamp] $message');
    if (_entries.length > 200) {
      _entries.removeRange(200, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// Renders [controller]'s entries in a collapsible card, newest first.
class LogPanel extends StatefulWidget {
  const LogPanel({super.key, required this.controller});

  final LogPanelController controller;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.entries;
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                dense: true,
                title: Text('Event log (${entries.length})'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Clear log',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: widget.controller.clear,
                    ),
                    IconButton(
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                SizedBox(
                  height: 180,
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            'Hook events will appear here as scenarios run.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: entries.length,
                          itemBuilder: (context, index) => Text(
                            entries[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
