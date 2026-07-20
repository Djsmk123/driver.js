/// A collapsible panel that renders a running log of hook/event firings.
/// Scenario code calls the sink this exposes (via [LogPanelController]) from
/// its `DriverConfig`/`DriveStep`/`HintsConfig` hooks, so a human watching
/// the demo can see hooks actually fire, not just take it on faith.
library;

import 'package:flutter/material.dart';

import 'app_design.dart';

/// Splits a raw `[hh:mm:ss.sss] message` log entry into its timestamp and
/// message parts so they can be styled differently (dimmed timestamp,
/// brighter accent-colored message) — shared by [LogPanel] and
/// `CupertinoLogPanel`.
({String timestamp, String message}) splitLogEntry(String entry) {
  final closingBracket = entry.indexOf(']');
  if (!entry.startsWith('[') || closingBracket == -1) {
    return (timestamp: '', message: entry);
  }
  return (
    timestamp: entry.substring(1, closingBracket),
    message: entry.substring(closingBracket + 1).trimLeft(),
  );
}

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
///
/// Mobile-first default: [initiallyExpanded] defaults to `false` so the
/// panel doesn't dominate a phone-sized viewport; callers on wide screens
/// (with room to spare) can pass `true` to start expanded.
class LogPanel extends StatefulWidget {
  const LogPanel({
    super.key,
    required this.controller,
    this.initiallyExpanded = false,
  });

  final LogPanelController controller;
  final bool initiallyExpanded;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    // A true near-black "terminal" surface in both light and dark theme —
    // reads as a distinct console widget rather than just a slightly-lighter
    // gray box, while the accent/dimmed text colors below keep contrast
    // comfortable against it either way.
    const consoleSurface = Color(0xFF1A1B26);
    const consoleBorder = Color(0xFF2E2F3E);
    const timestampColor = Color(0xFF7A7C99);
    const messageColor = Color(0xFFA5B4FC);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.entries;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: consoleSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: consoleBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacingMedium,
                  vertical: kSpacingSmall,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: consoleBorder)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 16, color: messageColor),
                    const SizedBox(width: kSpacingSmall),
                    Expanded(
                      child: Text(
                        'Event log (${entries.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear log',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: timestampColor,
                      ),
                      onPressed: widget.controller.clear,
                    ),
                    IconButton(
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: timestampColor,
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
                            style: TextStyle(color: timestampColor),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpacingMedium,
                            vertical: kSpacingSmall,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final parts = splitLogEntry(entries[index]);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (parts.timestamp.isNotEmpty)
                                      TextSpan(
                                        text: '[${parts.timestamp}] ',
                                        style: const TextStyle(
                                          color: timestampColor,
                                        ),
                                      ),
                                    TextSpan(
                                      text: parts.message,
                                      style: const TextStyle(
                                        color: messageColor,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
