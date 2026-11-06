import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'playing_card.dart';

/// The card counter (PRD §6.2, Rules §9.4): how many of each card are left in the deck and how
/// many are in the discard pile. Every card is played face up, so this hides nothing.
Future<void> showCardCounter(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.panel,
  barrierColor: AppColors.scrim,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
  builder: (_) => const _CardCounterSheet(),
);

class _CardCounterSheet extends ConsumerWidget {
  const _CardCounterSheet();

  static const _specials = [
    ('p2', CardKind.plus, 2),
    ('p4', CardKind.plus, 4),
    ('p6', CardKind.plus, 6),
    ('p8', CardKind.plus, 8),
    ('p10', CardKind.plus, 10),
    ('x2', CardKind.x2, 0),
    ('freeze', CardKind.freeze, 0),
    ('flip_three', CardKind.flipThree, 0),
    ('second_chance', CardKind.secondChance, 0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(roomProvider.select((s) => s.view));
    if (view == null) return const SizedBox.shrink();

    Widget entry(String key, GameCard card) =>
        _CounterEntry(card: card, inDeck: view.deck.counts[key] ?? 0, discarded: view.discard.counts[key] ?? 0);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: AppColors.panelBorder, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.cardCounter, style: AppText.title.copyWith(fontSize: 22)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Legend(color: AppColors.onTable, label: l10n.counterInDeck),
              const SizedBox(width: AppSpacing.md),
              _Legend(color: AppColors.onTableMuted, label: l10n.counterDiscarded),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.counterNumbers, style: AppText.heading),
          const SizedBox(height: AppSpacing.md),
          _Grid(
            children: [
              for (var v = 0; v <= 12; v++) entry('n$v', GameCard(id: 'counter-n$v', kind: CardKind.number, value: v)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.counterSpecial, style: AppText.heading),
          const SizedBox(height: AppSpacing.md),
          _Grid(
            children: [
              for (final (key, kind, value) in _specials)
                entry(key, GameCard(id: 'counter-$key', kind: kind, value: value)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Wrap(spacing: 12, runSpacing: 14, children: children),
  );
}

class _CounterEntry extends StatelessWidget {
  const _CounterEntry({required this.card, required this.inDeck, required this.discarded});

  final GameCard card;
  final int inDeck;
  final int discarded;

  @override
  Widget build(BuildContext context) {
    final empty = inDeck == 0;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          PlayingCard(card, width: 46, dimmed: empty, shadow: false),
          const SizedBox(height: 6),
          Text(
            '$inDeck',
            style: AppText.heading.copyWith(
              fontSize: 16,
              height: 1.1,
              color: empty ? AppColors.onTableMuted : AppColors.onTable,
            ),
          ),
          Text('$discarded', style: AppText.caption),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.label),
    ],
  );
}
