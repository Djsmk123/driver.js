/// The shared demo "stage" — the content every scenario highlights/tours
/// over. Exposes [StageKeys] so scenario code can build `DriveStep`s that
/// point at specific cards without reaching into the widget tree itself.
library;

import 'package:flutter/material.dart';

/// [GlobalKey]s for every element a scenario might want to highlight.
/// Constructed once by [StagePage] and handed to scenarios via
/// `ScenarioContext.keys`.
class StageKeys {
  final GlobalKey card1 = GlobalKey(debugLabel: 'card1');
  final GlobalKey card2 = GlobalKey(debugLabel: 'card2');
  final GlobalKey card3 = GlobalKey(debugLabel: 'card3');
  final GlobalKey card4 = GlobalKey(debugLabel: 'card4');
  final GlobalKey card5 = GlobalKey(debugLabel: 'card5');
  final GlobalKey card6 = GlobalKey(debugLabel: 'card6');

  final GlobalKey header = GlobalKey(debugLabel: 'header');
  final GlobalKey intro = GlobalKey(debugLabel: 'intro');
  final GlobalKey featureList = GlobalKey(debugLabel: 'featureList');
  final GlobalKey innerScrollList = GlobalKey(debugLabel: 'innerScrollList');
  final GlobalKey innerScrollItem3 = GlobalKey(debugLabel: 'innerScrollItem3');
  final GlobalKey belowFold = GlobalKey(debugLabel: 'belowFold');
  final GlobalKey lateElementSlot = GlobalKey(debugLabel: 'lateElementSlot');

  /// Only present in the tree once [StagePageState.mountLateElement] has
  /// been called — the actual target for `waitForElement`/
  /// `skipMissingElement` scenarios (unlike [lateElementSlot], which is
  /// always mounted as its placeholder container).
  final GlobalKey lateElement = GlobalKey(debugLabel: 'lateElement');

  List<GlobalKey> get cards => [card1, card2, card3, card4, card5, card6];
}

/// The scrollable page content every scenario runs its tour/highlight over.
/// Tall enough to require page scrolling on its own (for off-screen /
/// scroll-into-view scenarios), with a nested ~300px [ListView] (for
/// inner-scroll scenarios) and a togglable late-mounted card (for the
/// `waitForElement` scenario).
class StagePage extends StatefulWidget {
  const StagePage({super.key, required this.keys});

  final StageKeys keys;

  @override
  State<StagePage> createState() => StagePageState();
}

class StagePageState extends State<StagePage> {
  bool _lateElementMounted = false;

  void mountLateElement() => setState(() => _lateElementMounted = true);

  void unmountLateElement() => setState(() => _lateElementMounted = false);

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          key: keys.header,
          'driverjs demo stage',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          key: keys.intro,
          'This page is the shared stage every scenario in the sidebar runs '
          'against. Pick a scenario to see driverjs highlight, tour, and hint '
          'this content live.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StageCard(
              key: keys.card1,
              title: 'Card One',
              subtitle: 'The first highlightable card.',
              icon: Icons.looks_one,
            ),
            _StageCard(
              key: keys.card2,
              title: 'Card Two',
              subtitle: 'A second target for tours.',
              icon: Icons.looks_two,
            ),
            _StageCard(
              key: keys.card3,
              title: 'Card Three',
              subtitle: 'Useful for the transition scenario.',
              icon: Icons.looks_3,
            ),
            _StageCard(
              key: keys.card4,
              title: 'Card Four',
              subtitle: 'Try advanceOnClick on me.',
              icon: Icons.looks_4,
              onTap: () {},
            ),
            _StageCard(
              key: keys.card5,
              title: 'Card Five',
              subtitle: 'Popover position matrix target.',
              icon: Icons.looks_5,
            ),
            _StageCard(
              key: keys.card6,
              title: 'Card Six',
              subtitle: 'The last of the six cards.',
              icon: Icons.looks_6,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: keys.featureList,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Feature checklist',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _FeatureBullet('Single-element highlight'),
                _FeatureBullet('Multi-step guided tours'),
                _FeatureBullet('Popovers with custom content'),
                _FeatureBullet('Pulsing hint beacons'),
                _FeatureBullet('Keyboard navigation'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Inner scrollable region',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          key: keys.innerScrollList,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: 20,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  key: index == 3 ? keys.innerScrollItem3 : null,
                  dense: true,
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  title: Text('Inner scroll item ${index + 1}'),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Late-mounted element slot',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: keys.lateElementSlot,
          height: 64,
          child: _lateElementMounted
              ? Card(
                  key: keys.lateElement,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.bolt),
                    title: Text('Late element'),
                    subtitle: Text(
                      'Mounted after a delay for waitForElement demos.',
                    ),
                  ),
                )
              : const Card(
                  child: ListTile(
                    leading: Icon(Icons.hourglass_empty),
                    title: Text('(not mounted yet)'),
                  ),
                ),
        ),
        const SizedBox(height: 32),
        Text('Below the fold', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // Enough trailing filler that the page itself scrolls, so
        // off-screen/scroll-into-view scenarios have something to prove.
        for (var i = 0; i < 12; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              key: i == 8 ? widget.keys.belowFold : null,
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text('Filler section ${i + 1}'),
                subtitle: const Text(
                  'Scroll-into-view target lives further down this page.',
                ),
              ),
            ),
          ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
