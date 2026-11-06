import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/sounds.dart';
import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/table_motion.dart';
import '../widgets/ui.dart';

/// The results screen (PRD §4.6): the winner, the final standings, then Continue back to the room.
/// Confetti celebrates the winner, with a fanfare for the player if it's them (PRD §6.3–6.4).
class ResultsView extends ConsumerStatefulWidget {
  const ResultsView({super.key});

  @override
  ConsumerState<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<ResultsView> {
  @override
  void initState() {
    super.initState();
    final room = ref.read(roomProvider);
    final winners = room.view?.outcome?.winnerIds ?? const <String>[];
    final feedback = ref.read(gameFeedbackProvider);
    feedback.play(winners.contains(room.playerId) ? Sfx.win : Sfx.roundEnd);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final outcome = view.outcome;
    final winners = outcome?.winnerIds ?? const <String>[];
    // Only the players of this game: newcomers can already be waiting in the room (Rules §12.9).
    final played = outcome?.playerIds ?? const <String>[];
    final standings = [...view.players.where((p) => played.isEmpty || played.contains(p.id))]
      ..sort((a, b) {
        final aw = winners.contains(a.id) ? 0 : 1;
        final bw = winners.contains(b.id) ? 0 : 1;
        if (aw != bw) return aw - bw;
        final aLeft = a.status == PlayerStatus.left ? 1 : 0;
        final bLeft = b.status == PlayerStatus.left ? 1 : 0;
        if (aLeft != bLeft) return aLeft - bLeft;
        return b.total.compareTo(a.total);
      });
    final iWon = winners.contains(room.playerId) && !(outcome?.draw ?? false);
    final headline = outcome?.draw ?? false
        ? l10n.drawBetween(joinNames(l10n, winners.map((id) => displayName(l10n, view.player(id)))))
        : iWon
        ? l10n.youWon
        : displayName(l10n, view.player(winners.firstOrNull));
    final tutorial = view.tutorial;

    Future<void> leave() async {
      await ref.read(roomProvider.notifier).quit();
      if (context.mounted) context.go('/');
    }

    final results = SafeArea(
      child: ContentWidth(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.lg),
                children: [
                  Text(l10n.resultsTitle, style: AppText.label, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.16),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 40)],
                      ),
                      child: Icon(
                        outcome?.draw ?? false ? Icons.balance_rounded : Icons.emoji_events_rounded,
                        color: AppColors.gold,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!(outcome?.draw ?? false) && !iWon)
                    Text(l10n.winner, style: AppText.label, textAlign: TextAlign.center),
                  Text(headline, style: AppText.display.copyWith(fontSize: 32), textAlign: TextAlign.center),
                  if (tutorial) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      iWon ? l10n.tutorialWonBody : l10n.tutorialLostBody,
                      style: AppText.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        for (var i = 0; i < standings.length; i++)
                          _StandingRow(
                            rank: i + 1,
                            player: standings[i],
                            isMe: standings[i].id == room.playerId,
                            isWinner: winners.contains(standings[i].id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
              child: Column(
                children: [
                  // In the tutorial, Continue starts the next game against the bot right away (PRD §4.9).
                  AppButton(
                    label: tutorial ? l10n.playAgain : l10n.continueButton,
                    icon: tutorial ? Icons.replay_rounded : Icons.arrow_forward_rounded,
                    onPressed: ref.read(roomProvider.notifier).continueToRoom,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: tutorial ? l10n.goHome : l10n.leaveRoom,
                    icon: tutorial ? Icons.home_rounded : Icons.logout_rounded,
                    kind: AppButtonKind.quiet,
                    minHeight: AppSpacing.minTouch,
                    onPressed: leave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        results,
        const Positioned.fill(child: ConfettiBurst(pieces: 90, seed: 11, duration: Duration(milliseconds: 2400))),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.rank, required this.player, required this.isMe, required this.isWinner});

  final int rank;
  final PlayerView player;
  final bool isMe;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = player.status == PlayerStatus.left;
    return Opacity(
      opacity: left ? 0.55 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: AppText.heading.copyWith(color: isWinner ? AppColors.gold : AppColors.onTableMuted),
              ),
            ),
            PlayerAvatar(nickname: displayName(l10n, player), size: 34, highlight: isMe, bot: player.bot),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName(l10n, player),
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isMe ? AppColors.gold : AppColors.onTable,
                            ),
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 18),
                        ],
                      ],
                    ),
                    if (left) Text(l10n.statusLeft, style: AppText.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.pointsShort(player.total),
              style: AppText.heading.copyWith(color: isWinner ? AppColors.gold : AppColors.onTable),
            ),
          ],
        ),
      ),
    );
  }
}
