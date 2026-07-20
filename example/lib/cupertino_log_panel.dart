/// Cupertino-styled equivalent of [LogPanel] — same behavior (collapsible,
/// `initiallyExpanded` param, clear button, monospace log lines), built
/// entirely from `Container`/`CupertinoButton` (no `Card`/Material-specific
/// widgets).
library;

import 'package:flutter/cupertino.dart';

import 'log_panel.dart';

/// Renders [controller]'s entries in a collapsible Cupertino-styled panel,
/// newest first. Mirrors [LogPanel]'s mobile-first default:
/// [initiallyExpanded] defaults to `false`.
class CupertinoLogPanel extends StatefulWidget {
  const CupertinoLogPanel({
    super.key,
    required this.controller,
    this.initiallyExpanded = false,
  });

  final LogPanelController controller;
  final bool initiallyExpanded;

  @override
  State<CupertinoLogPanel> createState() => _CupertinoLogPanelState();
}

class _CupertinoLogPanelState extends State<CupertinoLogPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.entries;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.separator),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Event log (${entries.length})',
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: widget.controller.clear,
                      child: const Icon(CupertinoIcons.delete, size: 20),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 20,
                      ),
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
                            style: TextStyle(
                              color: CupertinoColors.inactiveGray,
                            ),
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
