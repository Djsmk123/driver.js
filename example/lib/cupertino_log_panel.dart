/// Cupertino-styled equivalent of [LogPanel] — same behavior (collapsible,
/// `initiallyExpanded` param, clear button, monospace log lines), built
/// entirely from `Container`/`CupertinoButton` (no `Card`/Material-specific
/// widgets).
library;

import 'package:flutter/cupertino.dart';

import 'app_design.dart';
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
    // Same "terminal" treatment as the Material LogPanel, kept in sync by eye
    // so both designs read as the same console widget.
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
            border: Border.all(color: consoleBorder),
            borderRadius: BorderRadius.circular(10),
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
                    const Icon(
                      CupertinoIcons.command,
                      size: 16,
                      color: messageColor,
                    ),
                    const SizedBox(width: kSpacingSmall),
                    Expanded(
                      child: Text(
                        'Event log (${entries.length})',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: widget.controller.clear,
                      child: const Icon(
                        CupertinoIcons.delete,
                        size: 20,
                        color: timestampColor,
                      ),
                    ),
                    const SizedBox(width: kSpacingSmall),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 20,
                        color: timestampColor,
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
