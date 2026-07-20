/// Cupertino-styled equivalent of [StagePage] — same [StageKeys], same
/// copy/section order/filler paragraphs (reusing [loremFiller] and
/// [scrollParagraphs] from `stage_page.dart` so the two stages can't
/// silently diverge), but built from Cupertino primitives so it looks right
/// mounted under a `CupertinoApp` chrome instead of Material's fallback
/// theme.
library;

import 'package:flutter/cupertino.dart';

import 'app_design.dart';
import 'stage_page.dart';

/// See [StagePage] — structurally identical, Cupertino-styled. Exposes the
/// exact same [StageKeys] object so every scenario file keeps working
/// unmodified against either stage page.
class CupertinoStagePage extends StatefulWidget {
  const CupertinoStagePage({super.key, required this.keys});

  final StageKeys keys;

  @override
  State<CupertinoStagePage> createState() => CupertinoStagePageState();
}

class CupertinoStagePageState extends State<CupertinoStagePage> {
  bool _lateElementMounted = false;

  void mountLateElement() => setState(() => _lateElementMounted = true);

  void unmountLateElement() => setState(() => _lateElementMounted = false);

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys;
    final textTheme = CupertinoTheme.of(context).textTheme;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return ListView(
      // See StagePage's cacheExtent comment — same reasoning applies here.
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
                children: [
                  Text(
                    'driver.js',
                    style: textTheme.navLargeTitleTextStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: kSpacingSmall),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacingSmall,
                        vertical: 2,
                      ),
                      child: Text(
                        'v1',
                        style: textTheme.textStyle.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
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
                style: textTheme.textStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpacingXLarge),
        Row(
          children: [
            Icon(CupertinoIcons.wand_stars, color: primaryColor, size: 20),
            const SizedBox(width: kSpacingSmall),
            Text('Highlight any element', style: textTheme.navTitleTextStyle),
          ],
        ),
        const SizedBox(height: kSpacingSmall),
        Text(
          key: keys.intro,
          'Highlight anything, anywhere on the page — literally anything, '
          'including SVG portions, scrollable items and off-screen '
          'elements. Pick an example from the sidebar to see it in action.',
          style: textTheme.textStyle,
        ),
        const SizedBox(height: kSpacingLarge),
        Wrap(
          spacing: kSpacingSmall + 4,
          runSpacing: kSpacingSmall + 4,
          children: [
            _CupertinoStageButton(stageKey: keys.card1, label: 'Card One'),
            _CupertinoStageButton(stageKey: keys.card2, label: 'Card Two'),
            _CupertinoStageButton(stageKey: keys.card3, label: 'Card Three'),
            _CupertinoStageButton(stageKey: keys.card4, label: 'Card Four'),
            _CupertinoStageButton(stageKey: keys.card5, label: 'Card Five'),
            _CupertinoStageButton(stageKey: keys.card6, label: 'Card Six'),
          ],
        ),
        const SizedBox(height: kSpacingLarge),
        Column(
          key: keys.featureList,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CupertinoBullet('Written in TypeScript'),
            _CupertinoBullet('Lightweight — only ~5kb gzipped'),
            _CupertinoBullet('No dependencies'),
            _CupertinoBullet('MIT Licensed'),
          ],
        ),
        const SizedBox(height: kSpacingMedium),
        _CupertinoBullet(
          'Watch the event log below to follow the hooks fired by an '
          'example.',
        ),
        const SizedBox(height: kSpacingLarge),
        Text(loremFiller, style: textTheme.textStyle),
        const SizedBox(height: kSpacingXLarge),
        Container(
          key: keys.innerScrollList,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.separator),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
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
                  style: textTheme.textStyle,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: kSpacingXLarge),
        Text(loremFiller, style: textTheme.textStyle),
        const SizedBox(height: kSpacingXLarge),
        SizedBox(
          key: keys.lateElementSlot,
          child: _lateElementMounted
              ? Text(
                  key: keys.lateElement,
                  'Late element — mounted after a delay for waitForElement '
                  'demos.',
                  style: textTheme.textStyle,
                )
              : Text(
                  '(late element not mounted yet)',
                  style: textTheme.textStyle.copyWith(
                    fontStyle: FontStyle.italic,
                    color: CupertinoColors.inactiveGray,
                  ),
                ),
        ),
        const SizedBox(height: kSpacingXLarge),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacingMedium),
            child: Text(
              key: i == 4 ? keys.belowFold : null,
              'Filler section ${i + 1} — scroll-into-view target lives '
              'further down this page. $loremFiller',
              style: textTheme.textStyle,
            ),
          ),
      ],
    );
  }
}

class _CupertinoBullet extends StatelessWidget {
  const _CupertinoBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacingTiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 18,
            color: CupertinoTheme.of(context).primaryColor,
          ),
          const SizedBox(width: kSpacingSmall),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// A bordered [CupertinoButton] with a subtle tinted background —
/// `CupertinoButton` alone has no outlined/filled variant, so this wraps it
/// in a [DecoratedBox] to read as a clearly-tappable iOS button (the
/// Cupertino counterpart of `StagePage`'s tonal `FilledButton`).
class _CupertinoStageButton extends StatelessWidget {
  const _CupertinoStageButton({required this.stageKey, required this.label});

  final GlobalKey stageKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return DecoratedBox(
      key: stageKey,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacingMedium,
          vertical: kSpacingSmall,
        ),
        onPressed: () {},
        child: Text(label, style: TextStyle(color: primaryColor)),
      ),
    );
  }
}
