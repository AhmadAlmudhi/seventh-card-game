import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'playing_card.dart';
import 'ui.dart';

/// The card counter (PRD §6.2, Rules §9.4): how many cards are left in the deck and in the discard
/// pile, then how many of each card. Every card is played face up, so this hides nothing.
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
    ('draw_three', CardKind.drawThree, 0),
    ('second_chance', CardKind.secondChance, 0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(roomProvider.select((s) => s.view));
    final myId = ref.watch(roomProvider.select((s) => s.playerId));
    if (view == null) return const SizedBox.shrink();
    // Numbers already in the player's row: another one would bust them (Rules §5.4).
    final held = {for (final c in view.player(myId)?.row ?? const <GameCard>[]) c.value};

    Widget entry(String key, GameCard card) => _CounterEntry(
      card: card,
      inDeck: view.deck.counts[key] ?? 0,
      discarded: view.discard.counts[key] ?? 0,
      held: card.isNumber && held.contains(card.value),
    );

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
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PileTotal(
                    label: l10n.counterLeftTotal,
                    count: view.deck.total,
                    card: const PlayingCard.back(width: 30, shadow: false, emblem: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PileTotal(
                    label: l10n.counterDiscardedTotal,
                    count: view.discard.total,
                    card: view.discard.top != null
                        ? PlayingCard(view.discard.top, width: 30, shadow: false)
                        : const _EmptyCard(width: 30),
                  ),
                ),
              ],
            ),
          ),
          if (view.decksInPlay > 1) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(label: l10n.secondDeckNote, icon: Icons.layers_rounded, color: AppColors.gold),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Legend(color: AppColors.onTable, label: l10n.counterInDeck),
              _Legend(color: AppColors.onTableMuted, label: l10n.counterDiscarded),
              if (held.isNotEmpty) _Legend(color: AppColors.danger, label: l10n.counterInRow, ring: true),
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
  const _CounterEntry({required this.card, required this.inDeck, required this.discarded, this.held = false});

  final GameCard card;
  final int inDeck;
  final int discarded;

  /// The player already has this number: it's the one that would bust them.
  final bool held;

  @override
  Widget build(BuildContext context) {
    final empty = inDeck == 0;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(46 * AppRadii.cardFraction),
              border: held ? Border.all(color: AppColors.danger, width: 2.5) : null,
            ),
            child: PlayingCard(card, width: 46, dimmed: empty, shadow: false),
          ),
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

/// One pile's total: a small card, the count, and what it is.
class _PileTotal extends StatelessWidget {
  const _PileTotal({required this.label, required this.count, required this.card});

  final String label;
  final int count;
  final Widget card;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadii.field),
      border: Border.all(color: AppColors.panelBorder),
    ),
    child: Row(
      children: [
        card,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count', style: AppText.title.copyWith(fontSize: 24, height: 1.15)),
              Text(label, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * PlayingCard.aspectRatio,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(width * AppRadii.cardFraction),
      border: Border.all(color: AppColors.panelBorder, width: 1.5),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.ring = false});

  final Color color;
  final String label;
  final bool ring;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: ring ? null : color,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: color, width: 2) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.label),
    ],
  );
}
