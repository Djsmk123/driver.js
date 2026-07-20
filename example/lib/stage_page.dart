/// The shared demo "stage" — the content every scenario highlights/tours
/// over. Mirrors driver.js's official playground `Stage.astro` (same
/// headline copy, section order, and filler paragraphs) rebuilt in
/// Flutter/Material terms. Exposes [StageKeys] so scenario code can build
/// `DriveStep`s that point at specific elements without reaching into the
/// widget tree itself.
library;

import 'package:flutter/material.dart';

import 'app_design.dart';

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

/// Shared with [CupertinoStagePage] so both stage implementations show the
/// identical filler copy rather than silently-diverging duplicates.
const loremFiller =
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Animi "
    'blanditiis consectetur ea eligendi id in inventore ipsa iure '
    'laudantium libero, minus molestias necessitatibus nesciunt non '
    'omnis, quasi recusandae tempore voluptates!';

/// Shared with [CupertinoStagePage] — see [loremFiller].
const scrollParagraphs = [
  'First — scroll down inside this box to reach the highlighted paragraph.',
  'Second — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Third — even nested scrollable elements are handled correctly.',
  'Fourth — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Fifth — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Sixth — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Seventh — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Eighth — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
  'Ninth — Lorem ipsum dolor sit amet, consectetur adipisicing elit.',
];

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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      // Generous cache extent: the off-screen/scroll-into-view scenarios
      // highlight a target several screens below the fold, and
      // `Scrollable.ensureVisible` (driven by driverjs's `bringInView`) can
      // only find a target that already has a laid-out RenderObject —
      // SliverList only keeps children within its cache extent mounted, so
      // the default (250px) leaves far-off targets un-built and the
      // scroll-into-view silently no-ops. This page is short enough that
      // keeping everything built is cheap.
      // ignore: deprecated_member_use
      cacheExtent: 4000,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacingMedium,
        vertical: kSpacingLarge,
      ),
      children: [
        Center(
          child: Column(
            key: keys.header,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'driver.js',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: kSpacingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacingSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v1',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacingSmall),
              Text(
                "A lightweight, no-dependency library to drive the user's "
                'focus across the page.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpacingXLarge),
        _SectionHeading(
          icon: Icons.highlight_alt,
          title: 'Highlight any element',
        ),
        const SizedBox(height: kSpacingSmall),
        Text(
          key: keys.intro,
          'Highlight anything, anywhere on the page — literally anything, '
          'including SVG portions, scrollable items and off-screen '
          'elements. Pick an example from the sidebar to see it in action.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: kSpacingLarge),
        Wrap(
          spacing: kSpacingSmall + 4,
          runSpacing: kSpacingSmall + 4,
          children: [
            _StageButton(stageKey: keys.card1, label: 'Card One'),
            _StageButton(stageKey: keys.card2, label: 'Card Two'),
            _StageButton(stageKey: keys.card3, label: 'Card Three'),
            _StageButton(stageKey: keys.card4, label: 'Card Four'),
            _StageButton(stageKey: keys.card5, label: 'Card Five'),
            _StageButton(stageKey: keys.card6, label: 'Card Six'),
          ],
        ),
        const SizedBox(height: kSpacingLarge),
        Column(
          key: keys.featureList,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Bullet('Written in TypeScript'),
            _Bullet('Lightweight — only ~5kb gzipped'),
            _Bullet('No dependencies'),
            _Bullet('MIT Licensed'),
          ],
        ),
        const SizedBox(height: kSpacingMedium),
        const _Bullet(
          'Watch the event log below to follow the hooks fired by an '
          'example.',
        ),
        const SizedBox(height: kSpacingLarge),
        Text(loremFiller, style: textTheme.bodyMedium),
        const SizedBox(height: kSpacingXLarge),
        Container(
          key: keys.innerScrollList,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            // Same reasoning as the outer ListView's cacheExtent above.
            // ignore: deprecated_member_use
            cacheExtent: 2000,
            padding: const EdgeInsets.all(kSpacingMedium),
            itemCount: scrollParagraphs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingSmall),
                child: Text(
                  key: index == 2 ? keys.innerScrollItem3 : null,
                  scrollParagraphs[index],
                  style: textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: kSpacingXLarge),
        Text(loremFiller, style: textTheme.bodyMedium),
        const SizedBox(height: kSpacingXLarge),
        SizedBox(
          key: keys.lateElementSlot,
          child: _lateElementMounted
              ? Text(
                  key: keys.lateElement,
                  'Late element — mounted after a delay for waitForElement '
                  'demos.',
                  style: textTheme.bodyMedium,
                )
              : Text(
                  '(late element not mounted yet)',
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
        ),
        const SizedBox(height: kSpacingXLarge),
        // Just enough trailing filler that the page itself scrolls, so
        // off-screen/scroll-into-view scenarios have something to prove.
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacingMedium),
            child: Text(
              key: i == 4 ? keys.belowFold : null,
              'Filler section ${i + 1} — scroll-into-view target lives '
              'further down this page. $loremFiller',
              style: textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// A section heading with a small colored icon accent, replacing the plain
/// `titleLarge` text that gave the stage no visual hierarchy beyond font
/// size.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: kSpacingSmall),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacingTiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: kSpacingSmall),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// The Flutter equivalent of the original playground's unstyled
/// `<button>Card One</button>` elements — a subtly-filled tonal button
/// (rather than a nearly-invisible outline) so it reads as clearly tappable.
class _StageButton extends StatelessWidget {
  const _StageButton({required this.stageKey, required this.label});

  final GlobalKey stageKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      key: stageKey,
      onPressed: () {},
      child: Text(label),
    );
  }
}
