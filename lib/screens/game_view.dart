import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../state/tutorial_coach.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/card_counter_sheet.dart';
import '../widgets/last_card_stage.dart';
import '../widgets/playing_card.dart';
import '../widgets/ui.dart';

const _hitOrStayMs = 15000;
const _chooseMs = 10000;

/// The game screen (PRD §6.2): opponents at the top, the last card revealed in the middle, and the
/// player's own row and controls at the bottom. Arabic mirrors it automatically.
class GameView extends ConsumerWidget {
  const GameView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(roomProvider.select((s) => s.view?.phase));
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        maxWidth: 560,
        child: Stack(
          children: [
            Column(
              children: [
                const _TopBar(),
                const _Opponents(),
                const Expanded(child: _TableCenter()),
                _CoachCard(maxHeight: MediaQuery.sizeOf(context).height * 0.26),
                const _MyPanel(),
              ],
            ),
            if (phase == Phase.roundOver) const Positioned.fill(child: _RoundSummary()),
            if (phase == Phase.paused) const Positioned.fill(child: _PausedOverlay()),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Top bar
// -----------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final tiebreak = view.tiebreak;

    Future<void> quit() async {
      final ok = await confirmDialog(
        context,
        title: l10n.quitConfirmTitle,
        body: l10n.quitConfirmBody,
        confirmLabel: l10n.quit,
        cancelLabel: l10n.keepPlaying,
        destructive: true,
      );
      if (!ok) return;
      await ref.read(roomProvider.notifier).quit();
      if (context.mounted) context.go('/');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, tooltip: l10n.quit, onPressed: quit),
          Expanded(
            child: Column(
              children: [
                Text(
                  tiebreak != null ? l10n.tiebreakLabel(tiebreak.roundNo) : l10n.roundLabel(view.round),
                  style: AppText.heading.copyWith(
                    fontSize: 16,
                    color: tiebreak != null ? AppColors.gold : AppColors.onTable,
                  ),
                ),
                Text(
                  view.tutorial ? l10n.tutorialLabel(view.targetScore) : l10n.roomLabel(room.code ?? ''),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SoundToggleButton(),
          const SizedBox(width: AppSpacing.xs),
          RoundIconButton(
            icon: Icons.style_rounded,
            tooltip: l10n.cardCounter,
            onPressed: () => showCardCounter(context),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Opponents
// -----------------------------------------------------------------------------

/// Every other player at once, in seat order after this player (PRD §6.2): one row for up to 4,
/// two rows of 3 or 4 for more, so nobody is ever off screen.
class _Opponents extends ConsumerWidget {
  const _Opponents();

  static const _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final me = room.me;
    final others = [
      ...view.players.where((p) => me != null && p.seat > me.seat),
      ...view.players.where((p) => me == null || p.seat < me.seat),
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    final myChoice = room.myDecision;
    final targetable = myChoice != null && myChoice.kind != DecisionKind.hitOrStay
        ? myChoice.targets.toSet()
        : const <String>{};
    final columns = others.length <= 4 ? others.length : (others.length <= 6 ? 3 : 4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final seatWidth = (constraints.maxWidth - _gap * (columns - 1)) / columns;
          final compact = seatWidth < 100;
          return Column(
            children: [
              for (var start = 0; start < others.length; start += columns)
                Padding(
                  padding: EdgeInsets.only(bottom: start + columns < others.length ? _gap : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = start; i < math.min(start + columns, others.length); i++) ...[
                        if (i > start) const SizedBox(width: _gap),
                        SizedBox(
                          width: seatWidth,
                          child: _Seat(
                            player: others[i],
                            view: view,
                            compact: compact,
                            wide: seatWidth > 220,
                            targetable: targetable.contains(others[i].id),
                            onTap: targetable.contains(others[i].id)
                                ? () => ref.read(roomProvider.notifier).choose(others[i].id)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.player,
    required this.view,
    required this.compact,
    required this.wide,
    required this.targetable,
    this.onTap,
  });

  final PlayerView player;
  final RoomView view;

  /// Four seats to a row (7 opponents): smaller type and cards.
  final bool compact;

  /// A single opponent across the whole width: bigger cards.
  final bool wide;
  final bool targetable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decision = view.decision;
    final acting =
        decision?.playerId == player.id ||
        (decision == null && view.turnPlayerId == player.id && view.phase == Phase.turns);
    final out =
        player.status == PlayerStatus.busted ||
        player.status == PlayerStatus.left ||
        player.status == PlayerStatus.watching;
    final chip = _statusChip(l10n, player, acting);
    final name = displayName(l10n, player);
    final avatar = compact ? 20.0 : 26.0;

    // Name on its own line, so large text never squeezes it out (PRD §6.5).
    final nameRow = Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatar(nickname: name, size: avatar, highlight: acting, bot: player.bot),
            if (view.dealerId == player.id)
              PositionedDirectional(
                bottom: compact ? -5 : -4,
                start: compact ? -7 : -5,
                child: Tooltip(
                  message: l10n.dealerTag,
                  child: Container(
                    padding: EdgeInsets.all(compact ? 1.5 : 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.panel, width: 1.5),
                    ),
                    child: Icon(Icons.style_rounded, size: compact ? 8 : 10, color: AppColors.onGold),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: compact ? 5 : 6),
        Expanded(
          child: Text(
            name,
            style: AppText.label.copyWith(
              color: AppColors.onTable,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12.5 : 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (player.forced) Icon(Icons.whatshot_rounded, size: compact ? 13 : 15, color: AppColors.flipThree),
      ],
    );
    final cards = SizedBox(
      height: compact ? 22 : (wide ? 36 : 28),
      child: _MiniRow(player: player, cardWidth: compact ? 16 : (wide ? 26 : 20)),
    );
    // Always the same height, so every seat in a row lines up.
    final chipLine = SizedBox(
      height: compact ? 19 : 21,
      child: chip == null
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: compact ? FittedBox(fit: BoxFit.scaleDown, child: chip) : chip,
            ),
    );
    final gap = SizedBox(height: compact ? 5 : 7);
    final scores = _SeatScores(player: player, compact: compact);

    // A single opponent gets the whole width: name and cards on one side, scores on the other.
    final content = wide
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [nameRow, const SizedBox(height: 8), cards],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 136,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [scores, const SizedBox(height: 8), chipLine],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [nameRow, gap, cards, gap, scores, gap, chipLine],
          );

    return Semantics(
      button: onTap != null,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: targetable ? 1.04 : 1,
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          child: Panel(
            padding: EdgeInsets.all(compact ? 7 : (wide ? 12 : 10)),
            highlight: targetable ? AppColors.info : (acting ? AppColors.gold : null),
            child: Opacity(opacity: out ? 0.6 : 1, child: content),
          ),
        ),
      ),
    );
  }

  static Widget? _statusChip(AppLocalizations l10n, PlayerView p, bool acting) {
    if (!p.connected && p.status != PlayerStatus.left) {
      return StatusChip(label: l10n.statusReconnecting, icon: Icons.wifi_off_rounded);
    }
    return switch (p.status) {
      PlayerStatus.stayed => StatusChip(label: l10n.statusStayed, icon: Icons.check_rounded),
      PlayerStatus.frozen => StatusChip(label: l10n.statusFrozen, icon: Icons.ac_unit_rounded, color: AppColors.freeze),
      PlayerStatus.busted => StatusChip(
        label: l10n.statusBusted,
        icon: Icons.local_fire_department_rounded,
        color: AppColors.danger,
      ),
      PlayerStatus.left => StatusChip(label: l10n.statusLeft, icon: Icons.logout_rounded),
      PlayerStatus.watching => StatusChip(label: l10n.statusWatching, icon: Icons.visibility_rounded),
      PlayerStatus.active when p.seventhCard => StatusChip(
        label: l10n.seventhCard,
        icon: Icons.auto_awesome_rounded,
        color: AppColors.gold,
        filled: true,
      ),
      PlayerStatus.active when acting => StatusChip(
        label: l10n.statusTurn,
        icon: Icons.timer_rounded,
        color: AppColors.gold,
        filled: true,
      ),
      PlayerStatus.active => null,
    };
  }
}

/// A seat's round score so far and its total, each labelled (PRD §6.2).
class _SeatScores extends StatelessWidget {
  const _SeatScores({required this.player, required this.compact});

  final PlayerView player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sitsOut = player.status == PlayerStatus.watching || player.status == PlayerStatus.left;
    final score = player.roundScore;
    final round = sitsOut ? '–' : (score > 0 ? '+$score' : '$score');
    final roundColor = player.status == PlayerStatus.busted ? AppColors.danger : AppColors.onTable;
    return Row(
      children: [
        Expanded(
          child: _Stat(label: l10n.seatRound, value: round, color: roundColor, compact: compact),
        ),
        Container(width: 1, height: compact ? 22 : 26, color: AppColors.panelBorder),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: _Stat(label: l10n.seatTotal, value: '${player.total}', color: AppColors.gold, compact: compact),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, required this.compact});

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.caption.copyWith(fontSize: compact ? 10 : 11, height: 1.2)),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppText.numeral(compact ? 15 : 17, color).copyWith(height: 1.15),
        ),
      ],
    ),
  );
}

/// A seat's cards, overlapped so a full row of seven fits.
class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.player, required this.cardWidth});

  final PlayerView player;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ...player.row,
      if (player.bustCard != null) player.bustCard!,
      ...player.modifiers,
      if (player.secondChance != null) player.secondChance!,
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    final width = cardWidth;
    // Overlapped just enough that a two-digit number stays readable; a long row shrinks to fit.
    final step = width * 0.8;
    // Aligned to the reading start; the cards themselves are always left-to-right (PRD §6.6).
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width + step * (cards.length - 1),
            height: width * PlayingCard.aspectRatio,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    key: ValueKey(cards[i].id),
                    left: i * step,
                    child: PlayingCard(cards[i], width: width, shadow: false, dimmed: cards[i] == player.bustCard),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Table centre
// -----------------------------------------------------------------------------

/// The middle of the table (PRD §6.2): the card revealed last, then what's happening now. The
/// deck and discard counts live in the card counter.
class _TableCenter extends ConsumerWidget {
  const _TableCenter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final flipThree = view.flipThrees.isEmpty ? null : view.flipThrees.last;
    final chips = [
      if (flipThree != null)
        StatusChip(
          label: l10n.flipThreeProgress(flipThree.remaining),
          icon: Icons.autorenew_rounded,
          color: AppColors.flipThree,
        ),
      if (view.decksInPlay > 1)
        StatusChip(label: l10n.secondDeckNote, icon: Icons.layers_rounded, color: AppColors.gold),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final reserved = (40 + 26) * textScale + 14 + 16 + (chips.isEmpty ? 0 : 30 * textScale);
        final cardWidth = ((constraints.maxHeight - reserved) / PlayingCard.aspectRatio).clamp(34.0, 96.0);
        // Scales down rather than overflowing on the shortest screens.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Stage(cardWidth: cardWidth),
                  const SizedBox(height: 14),
                  _StatusLine(room: room),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: chips),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The last card revealed, with whose it is underneath.
class _Stage extends ConsumerWidget {
  const _Stage({required this.cardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // A record, so this rebuilds only when the card or what it did changes.
    final stage = ref.watch(
      roomProvider.select((s) {
        final draw = s.view?.lastDraw;
        if (draw == null) return null;
        final owner = s.view!.player(draw.playerId);
        return (
          card: draw.card,
          effect: stageEffectFor(draw, owner),
          mine: draw.playerId == s.playerId,
          name: displayName(l10n, owner),
          bot: owner?.bot ?? false,
        );
      }),
    );
    final effect = stage?.effect ?? StageEffect.plain;
    final stamp = switch (effect) {
      StageEffect.bust => stage!.mine ? l10n.bust : l10n.stageBust,
      StageEffect.saved => l10n.stageSaved,
      StageEffect.seventh => l10n.seventhCard,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LastCardStage(card: stage?.card, effect: effect, width: cardWidth, stampLabel: stamp),
        const SizedBox(height: 10),
        SizedBox(
          height: 26,
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: stage == null
                ? Text(l10n.lastCardWaiting, key: const ValueKey('waiting'), style: AppText.caption)
                : Row(
                    key: ValueKey('${stage.card.id}-${stage.name}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerAvatar(nickname: stage.name, size: 20, highlight: stage.mine, bot: stage.bot),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          stage.mine ? l10n.lastCardMine : l10n.lastCardOf(isolate(stage.name)),
                          style: AppText.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.width});

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

/// What's happening right now, with the server's countdown when someone has a decision. The
/// tutorial has no turn timer: the player gets a hand icon, and the bot a "thinking" spinner.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = room.view!;
    final decision = view.decision;
    final owner = view.player(decision?.playerId);
    final mine = decision != null && decision.playerId == room.playerId;

    final String text;
    if (decision == null) {
      text = l10n.dealing;
    } else if (mine) {
      text = switch (decision.kind) {
        DecisionKind.hitOrStay => l10n.yourTurn,
        DecisionKind.chooseTarget => decision.card?.kind == CardKind.freeze ? l10n.chooseFreeze : l10n.chooseFlipThree,
        DecisionKind.giveSecondChance => l10n.chooseSecondChance,
      };
    } else {
      final name = isolate(displayName(l10n, owner));
      text = decision.kind == DecisionKind.hitOrStay ? l10n.turnOf(name) : l10n.waitingChoice(name);
    }

    const spinner = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
    );
    final Widget leading;
    if (decision == null || (view.tutorial && (owner?.bot ?? false))) {
      leading = spinner;
    } else if (view.tutorial) {
      leading = const Icon(Icons.touch_app_rounded, size: 20, color: AppColors.gold);
    } else {
      leading = TimerRing(
        deadline: decision.deadline,
        totalMs: decision.kind == DecisionKind.hitOrStay ? _hitOrStayMs : _chooseMs,
        clockOffsetMs: room.clockOffsetMs,
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: Container(
        key: ValueKey('${decision?.id}-$mine'),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 16, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.gold.withValues(alpha: 0.16) : AppColors.panel.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: mine ? AppColors.gold.withValues(alpha: 0.6) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(text, style: AppText.heading.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tutorial's tip for this moment (PRD §4.9), between the table and the player's cards. It
/// never takes more than [maxHeight], so the table and the player's controls always fit.
class _CoachCard extends ConsumerWidget {
  const _CoachCard({required this.maxHeight});

  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tutorial = ref.watch(roomProvider.select((s) => s.view?.tutorial ?? false));
    final tip = ref.watch(tutorialCoachProvider.select((s) => s.current));
    final reduced = MediaQuery.disableAnimationsOf(context);

    final switcher = AnimatedSwitcher(
      duration: reduced ? AppMotion.fast : AppMotion.medium,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: reduced
            ? child
            : SlideTransition(
                position: animation.drive(Tween(begin: const Offset(0, 0.15), end: Offset.zero)),
                child: child,
              ),
      ),
      child: !tutorial || tip == null
          ? const SizedBox(width: double.infinity, key: ValueKey('no-tip'))
          : Padding(
              key: ValueKey(tip),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lightbulb_rounded, size: 17, color: AppColors.gold),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _title(l10n, tip),
                            style: AppText.heading.copyWith(fontSize: 15, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppButton(
                          label: l10n.tipGotIt,
                          kind: AppButtonKind.secondary,
                          dense: true,
                          expand: false,
                          minHeight: 40,
                          onPressed: ref.read(tutorialCoachProvider.notifier).dismiss,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Scrolls only if the largest text sizes make it taller than its share of the screen.
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(_body(l10n, tip), style: AppText.bodyMuted.copyWith(fontSize: 14, height: 1.45)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: switcher,
    );
  }

  static String _title(AppLocalizations l10n, CoachTip tip) => switch (tip) {
    CoachTip.welcome => l10n.tipWelcomeTitle,
    CoachTip.turn => l10n.tipTurnTitle,
    CoachTip.risk => l10n.tipRiskTitle,
    CoachTip.bust => l10n.tipBustTitle,
    CoachTip.freeze => l10n.tipFreezeTitle,
    CoachTip.flipThree => l10n.tipFlipThreeTitle,
    CoachTip.secondChance => l10n.tipSecondChanceTitle,
    CoachTip.modifier => l10n.tipModifierTitle,
    CoachTip.seventh => l10n.tipSeventhTitle,
  };

  static String _body(AppLocalizations l10n, CoachTip tip) => switch (tip) {
    CoachTip.welcome => l10n.tipWelcomeBody,
    CoachTip.turn => l10n.tipTurnBody,
    CoachTip.risk => l10n.tipRiskBody,
    CoachTip.bust => l10n.tipBustBody,
    CoachTip.freeze => l10n.tipFreezeBody,
    CoachTip.flipThree => l10n.tipFlipThreeBody,
    CoachTip.secondChance => l10n.tipSecondChanceBody,
    CoachTip.modifier => l10n.tipModifierBody,
    CoachTip.seventh => l10n.tipSeventhBody,
  };
}

// -----------------------------------------------------------------------------
// The player's own area
// -----------------------------------------------------------------------------

class _MyPanel extends ConsumerStatefulWidget {
  const _MyPanel();

  @override
  ConsumerState<_MyPanel> createState() => _MyPanelState();
}

class _MyPanelState extends ConsumerState<_MyPanel> {
  /// Which button was tapped, so it can show it's working while the server answers.
  String? _tapped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final me = room.me;
    if (me == null) return const SizedBox.shrink();
    final controller = ref.read(roomProvider.notifier);
    final decision = room.myDecision;
    final pending = room.pendingDecisionId != null && room.pendingDecisionId == view.decision?.id;
    final choosing = decision != null && decision.kind != DecisionKind.hitOrStay;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        border: Border(top: BorderSide(color: AppColors.panelBorder)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Both sides give way on narrow screens or large text, so nothing overflows.
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Text(l10n.you, style: AppText.title.copyWith(fontSize: 20)),
                    const SizedBox(width: 10),
                    Flexible(child: StatusChip(label: l10n.totalScore(me.total))),
                    if (me.forced) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: StatusChip(
                          label: l10n.forcedBadge,
                          icon: Icons.whatshot_rounded,
                          color: AppColors.flipThree,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: _MyRoundScore(me: me),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MyCards(me: me),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: AppMotion.medium,
            switchInCurve: AppMotion.enter,
            child: me.status == PlayerStatus.watching
                ? Padding(
                    key: const ValueKey('watching'),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(l10n.watchingTiebreak, style: AppText.body),
                  )
                : choosing
                ? _TargetChooser(
                    key: ValueKey(decision.id),
                    decision: decision,
                    view: view,
                    onChoose: controller.choose,
                  )
                : Row(
                    key: const ValueKey('hit-stay'),
                    children: [
                      Expanded(
                        child: AppButton(
                          label: l10n.hit,
                          icon: Icons.add_rounded,
                          minHeight: 60,
                          loading: pending && _tapped == 'hit',
                          onPressed: decision != null && !pending
                              ? () {
                                  setState(() => _tapped = 'hit');
                                  controller.hit();
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: l10n.stay,
                          icon: Icons.front_hand_rounded,
                          kind: AppButtonKind.secondary,
                          minHeight: 60,
                          loading: pending && _tapped == 'stay',
                          onPressed: decision != null && decision.canStay && !pending
                              ? () {
                                  setState(() => _tapped = 'stay');
                                  controller.stay();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MyRoundScore extends StatelessWidget {
  const _MyRoundScore({required this.me});

  final PlayerView me;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (me.status == PlayerStatus.busted) {
      return Text(l10n.bust, style: AppText.score.copyWith(color: AppColors.danger, fontSize: 20));
    }
    final score = me.roundScore;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Text(
            score >= 0 ? '+$score' : '$score',
            key: ValueKey(score),
            textDirection: TextDirection.ltr,
            style: AppText.score,
          ),
        ),
        const SizedBox(width: 6),
        Text(l10n.thisRound, style: AppText.caption),
      ],
    );
  }
}

class _MyCards extends StatelessWidget {
  const _MyCards({required this.me});

  final PlayerView me;

  @override
  Widget build(BuildContext context) {
    final extras = [if (me.secondChance != null) me.secondChance!, ...me.modifiers];
    final numbers = [...me.row, if (me.bustCard != null) me.bustCard!];
    final busted = me.status == PlayerStatus.busted;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Up to 7 numbers (8 with the duplicate that busted) must fit in one row.
        final slots = numbers.length < 5 ? 5 : numbers.length;
        final width = ((constraints.maxWidth - (slots - 1) * 8) / slots).clamp(30.0, 64.0);
        return Column(
          children: [
            if (extras.isNotEmpty) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 8, children: [for (final card in extras) PlayingCard(card, width: 36)]),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: width * PlayingCard.aspectRatio,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < numbers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      numbers[i] == me.bustCard
                          ? DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(width * AppRadii.cardFraction),
                                border: Border.all(color: AppColors.danger, width: 3),
                              ),
                              child: PlayingCard(numbers[i], width: width),
                            )
                          : PlayingCard(numbers[i], width: width, dimmed: busted),
                    ],
                    if (numbers.isEmpty) _EmptySlot(width: width),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Choosing who gets a Freeze, Flip Three or extra Second Chance. Seats can be tapped too.
class _TargetChooser extends StatelessWidget {
  const _TargetChooser({super.key, required this.decision, required this.view, required this.onChoose});

  final Decision decision;
  final RoomView view;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (decision.kind) {
      DecisionKind.giveSecondChance => l10n.chooseSecondChance,
      _ => decision.card?.kind == CardKind.freeze ? l10n.chooseFreeze : l10n.chooseFlipThree,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (decision.card != null) ...[
              PlayingCard(decision.card, width: 30, shadow: false),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title, style: AppText.heading)),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.chooseHint, style: AppText.caption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in decision.targets)
              _TargetButton(
                nickname: displayName(l10n, view.player(id)),
                bot: view.player(id)?.bot ?? false,
                label: id == decision.playerId ? l10n.you : displayName(l10n, view.player(id)),
                onTap: () => onChoose(id),
              ),
          ],
        ),
      ],
    );
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({required this.nickname, required this.bot, required this.label, required this.onTap});

  final String nickname;
  final bool bot;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Ink(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(nickname: nickname, size: 30, bot: bot),
            const SizedBox(width: 8),
            Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Overlays
// -----------------------------------------------------------------------------

class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.medium,
    curve: AppMotion.enter,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: ColoredBox(
        color: AppColors.scrim.withValues(alpha: 0.55 * t),
        child: Center(
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
            border: Border.all(color: AppColors.panelBorder),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// The break between rounds (PRD §8.4.1): every round score, then the next round starts.
class _RoundSummary extends ConsumerWidget {
  const _RoundSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final scored = view.players.where((p) => view.roundPlayerIds.contains(p.id)).toList()
      ..sort((a, b) => b.roundScore.compareTo(a.roundScore));

    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.roundScoresTitle(view.round),
            style: AppText.title.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final p in scored)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  PlayerAvatar(nickname: displayName(l10n, p), size: 30, highlight: p.id == room.playerId, bot: p.bot),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.id == room.playerId ? l10n.you : displayName(l10n, p),
                      style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p.seventhCard)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 6),
                      child: Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 18),
                    ),
                  Text(
                    p.status == PlayerStatus.busted
                        ? l10n.bust
                        : (p.roundScore >= 0 ? '+${p.roundScore}' : '${p.roundScore}'),
                    textDirection: p.status == PlayerStatus.busted ? null : TextDirection.ltr,
                    style: AppText.heading.copyWith(
                      color: p.status == PlayerStatus.busted ? AppColors.danger : AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    child: Text('${p.total}', textAlign: TextAlign.end, style: AppText.label),
                  ),
                ],
              ),
            ),
          if (view.tiebreak != null) ...[
            const SizedBox(height: AppSpacing.md),
            StatusChip(
              label: l10n.tiebreakStarting(
                joinNames(l10n, view.tiebreak!.playerIds.map((id) => displayName(l10n, view.player(id)))),
              ),
              icon: Icons.balance_rounded,
              color: AppColors.gold,
            ),
          ],
          if (view.tutorial) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 3, end: 8),
                  child: Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.gold),
                ),
                Expanded(child: Text(l10n.tutorialRoundNote, style: AppText.bodyMuted.copyWith(fontSize: 14))),
              ],
            ),
          ],
          if (view.nextRoundAt != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Countdown(
              deadline: view.nextRoundAt!,
              clockOffsetMs: room.clockOffsetMs,
              builder: (s) => l10n.nextRoundIn(s),
            ),
          ],
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.gold, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.pausedTitle, style: AppText.title.copyWith(fontSize: 22), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.pausedBody, style: AppText.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// A countdown line to a server deadline.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.deadline, required this.clockOffsetMs, required this.builder});

  final int deadline;
  final int clockOffsetMs;
  final String Function(int seconds) builder;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.deadline - (DateTime.now().millisecondsSinceEpoch + widget.clockOffsetMs);
    final seconds = (ms / 1000).ceil().clamp(0, 99);
    return Text(widget.builder(seconds), style: AppText.bodyMuted, textAlign: TextAlign.center);
  }
}
