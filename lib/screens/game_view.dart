import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/sounds.dart';
import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../state/table_director.dart';
import '../state/tutorial_coach.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/card_counter_sheet.dart';
import '../widgets/last_card_stage.dart';
import '../widgets/playing_card.dart';
import '../widgets/table_motion.dart';
import '../widgets/ui.dart';

const _hitOrStayMs = 15000;
const _chooseMs = 10000;

/// The game screen (PRD §6.2): opponents at the top, the last card revealed in the middle, and the
/// player's own row and controls at the bottom. Arabic mirrors it automatically.
///
/// It draws the table director's view, which plays the server's events one beat at a time
/// (PRD §9.3), and plays each beat's sound and haptic.
class GameView extends ConsumerStatefulWidget {
  const GameView({super.key});

  @override
  ConsumerState<GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<GameView> with SingleTickerProviderStateMixin {
  /// A quick fade when playback skips ahead (PRD §6.3).
  late final AnimationController _skipFade = AnimationController(vsync: this, duration: AppMotion.medium, value: 1);

  @override
  void initState() {
    super.initState();
    // Sounds load as the table opens, so the first card already has its sound (PRD §6.4).
    ref.read(gameFeedbackProvider).preload();
  }

  @override
  void dispose() {
    _skipFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.read(tableDirectorProvider.notifier).reducedMotion = MediaQuery.disableAnimationsOf(context);
    ref.listen(tableDirectorProvider.select((s) => s.skips), (_, _) => _skipFade.forward(from: 0.35));
    final phase = ref.watch(tableViewProvider.select((v) => v?.phase));
    return TableGeometry(
      child: _TableFeedback(
        child: SafeArea(
          bottom: false,
          child: ContentWidth(
            maxWidth: 560,
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _skipFade,
                  child: Column(
                    children: [
                      const _TopBar(),
                      const _Opponents(),
                      const Expanded(child: _TableCenter()),
                      _CoachCard(maxHeight: MediaQuery.sizeOf(context).height * 0.26),
                      const _MyPanel(),
                    ],
                  ),
                ),
                if (phase == Phase.roundOver) const Positioned.fill(child: _RoundSummary()),
                if (phase == Phase.paused) const Positioned.fill(child: _PausedOverlay()),
                const Positioned.fill(child: _SeventhCelebration()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sounds, haptics and screen-reader announcements for each beat (PRD §6.4–6.5).
class _TableFeedback extends ConsumerWidget {
  const _TableFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tableDirectorProvider.select((s) => s.cue), (_, cue) {
      if (cue == null) return;
      final feedback = ref.read(gameFeedbackProvider);
      final l10n = AppLocalizations.of(context);
      final myId = ref.read(roomProvider).playerId;
      final mine = cue.playerId == myId;
      final data = cue.event.data;
      switch (cue.type) {
        case 'cardDealt':
          final card = GameCard.fromJson(data['card'] as Map<String, dynamic>);
          if (card.isAction) {
            feedback.play(Sfx.action);
          } else if (!card.isNumber) {
            feedback.play(Sfx.bonus);
          } else if (data['source'] != 'deal') {
            feedback.play(Sfx.flip);
          }
        case 'busted':
          feedback.play(Sfx.bust);
          if (mine) {
            feedback.buzz(Buzz.bust);
            _announce(context, l10n.bust);
          }
        case 'frozen':
          feedback.play(Sfx.freeze);
          if (mine) _announce(context, l10n.announceFrozen);
        case 'secondChanceUsed':
          feedback.play(Sfx.saved);
        case 'secondChanceKept' || 'secondChanceGiven':
          feedback.play(Sfx.bonus);
        case 'stayed' || 'autoStayed':
          feedback.play(Sfx.stay);
        case 'seventhCard':
          feedback.play(Sfx.seventh);
          if (mine) feedback.buzz(Buzz.seventh);
          _announce(context, l10n.seventhCard);
        case 'actionPlayed':
          feedback.play(Sfx.action);
        case 'reshuffled' || 'extraDeckAdded' || 'deckReset':
          feedback.play(Sfx.shuffle);
        case 'roundScored':
          feedback.play(Sfx.roundEnd);
        case 'decisionRequested':
          if ((data['decision'] as Map<String, dynamic>)['playerId'] == myId) {
            feedback.play(Sfx.turn);
            feedback.buzz(Buzz.turn);
            _announce(context, l10n.yourTurn);
          }
      }
    });
    return child;
  }

  static void _announce(BuildContext context, String message) =>
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
}

// -----------------------------------------------------------------------------
// Top bar
// -----------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final code = ref.watch(roomProvider.select((s) => s.code));
    final view = ref.watch(tableViewProvider)!;
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
                  view.tutorial ? l10n.tutorialLabel(view.targetScore) : l10n.roomLabel(code ?? ''),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SoundToggleButton(),
          const SizedBox(width: AppSpacing.xs),
          RoundIconButton(
            key: TableGeometry.maybeOf(context)?.counterKey,
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
    final view = ref.watch(tableViewProvider)!;
    final me = view.player(ref.watch(roomProvider.select((s) => s.playerId)));
    final others = [
      ...view.players.where((p) => me != null && p.seat > me.seat),
      ...view.players.where((p) => me == null || p.seat < me.seat),
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    final myChoice = ref.watch(myDecisionProvider);
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
        _FlipThreeBadge(view: view, playerId: player.id, size: compact ? 18 : 22),
      ],
    );
    final cards = SizedBox(
      height: compact ? 22 : (wide ? 36 : 28),
      child: _MiniRow(player: player, cardWidth: compact ? 16 : (wide ? 26 : 20)),
    );
    // Always the same height, so every seat in a row lines up. A new status pops in.
    final chipLine = SizedBox(
      height: compact ? 19 : 21,
      child: _PopSwitcher(
        child: chip == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Align(
                key: ValueKey(player.status),
                alignment: AlignmentDirectional.centerStart,
                child: compact ? FittedBox(fit: BoxFit.scaleDown, child: chip) : chip,
              ),
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
          child: _SeatEffects(
            playerId: player.id,
            frozen: player.status == PlayerStatus.frozen,
            child: Panel(
              padding: EdgeInsets.all(compact ? 7 : (wide ? 12 : 10)),
              highlight: targetable ? AppColors.info : (acting ? AppColors.gold : null),
              child: Opacity(opacity: out ? 0.6 : 1, child: content),
            ),
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

/// A seat's one-off effects (PRD §6.3): a shake and red flash on a bust, frost spreading over it
/// on a Freeze, and a pulse when an action card or a Second Chance comes its way. A frozen seat
/// keeps a cool tint. Only the wrapper repaints while an effect runs.
class _SeatEffects extends StatelessWidget {
  const _SeatEffects({required this.playerId, required this.frozen, required this.child, this.radius});

  final String playerId;
  final bool frozen;
  final Widget child;
  final BorderRadius? radius;

  bool _matches(TableCue cue) => switch (cue.type) {
    'busted' || 'frozen' => cue.playerId == playerId,
    'actionPlayed' => cue.event.data['target'] == playerId,
    'secondChanceGiven' => cue.event.data['to'] == playerId,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final radius = this.radius ?? BorderRadius.circular(AppRadii.panel);
    final rest = BoxDecoration(
      borderRadius: radius,
      color: frozen ? AppColors.freeze.withValues(alpha: 0.07) : null,
      border: frozen ? Border.all(color: AppColors.freeze.withValues(alpha: 0.45), width: 1.5) : null,
    );
    // The same widgets wrap the seat whether or not an effect is playing, so its cards never get
    // rebuilt from scratch when one starts or ends.
    Widget frame({required Matrix4 transform, required Decoration decoration, required Widget child}) => Transform(
      alignment: Alignment.center,
      transform: transform,
      child: DecoratedBox(position: DecorationPosition.foreground, decoration: decoration, child: child),
    );
    return CueEffect(
      matches: _matches,
      duration: AppMotion.bust,
      // The seat keeps its own layer: an effect only repaints the overlay drawn on top of it.
      child: RepaintBoundary(child: child),
      builder: (context, t, cue, child) {
        if (t >= 1 || cue == null) return frame(transform: Matrix4.identity(), decoration: rest, child: child!);
        switch (cue.type) {
          case 'busted':
            final shake = math.sin(t * math.pi * 6) * 6 * (1 - t);
            return frame(
              transform: Matrix4.translationValues(shake, 0, 0),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: AppColors.danger.withValues(alpha: 0.35 * (1 - t)),
              ),
              child: child!,
            );
          case 'frozen':
            // Frost spreads down from the top, then settles into the frozen tint.
            final spread = Curves.easeOutCubic.transform(math.min(1, t * 1.6));
            return frame(
              transform: Matrix4.identity(),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: rest.border,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, spread, math.min(1, spread + 0.25)],
                  colors: [
                    AppColors.freeze.withValues(alpha: 0.45 * (1 - t * 0.7)),
                    AppColors.freeze.withValues(alpha: 0.25 * (1 - t * 0.7)),
                    AppColors.freeze.withValues(alpha: 0.07),
                  ],
                ),
              ),
              child: child!,
            );
          default:
            final pulse = math.sin(t * math.pi);
            final color = cue.type == 'secondChanceGiven'
                ? AppColors.secondChance
                : (cue.event.data['card'] as Map<String, dynamic>?)?['action'] == 'freeze'
                ? AppColors.freeze
                : AppColors.flipThree;
            final scale = 1 + 0.05 * pulse;
            return frame(
              transform: Matrix4.diagonal3Values(scale, scale, 1),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: rest.color,
                border: Border.all(color: color.withValues(alpha: pulse), width: 2.5),
              ),
              child: child!,
            );
        }
      },
    );
  }
}

/// Flip Three's countdown on its target: 3, 2, 1 (PRD §6.3).
class _FlipThreeBadge extends StatelessWidget {
  const _FlipThreeBadge({required this.view, required this.playerId, required this.size});

  final RoomView view;
  final String playerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final entry = view.flipThrees.where((f) => f.playerId == playerId).lastOrNull;
    return _PopSwitcher(
      child: entry == null || entry.remaining <= 0
          ? const SizedBox.shrink(key: ValueKey(-1))
          : Container(
              key: ValueKey(entry.remaining),
              width: size,
              height: size,
              margin: const EdgeInsetsDirectional.only(start: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.flipThree, shape: BoxShape.circle),
              child: Text(
                '${entry.remaining}',
                style: AppText.numeral(size * 0.6, AppColors.onGold),
                textDirection: TextDirection.ltr,
              ),
            ),
    );
  }
}

/// Switches its child with a quick fade and a springy scale: badges and status chips popping in.
class _PopSwitcher extends StatelessWidget {
  const _PopSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.medium,
    switchInCurve: AppMotion.spring,
    switchOutCurve: AppMotion.exit,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation.drive(Tween(begin: 0.6, end: 1.0)), child: child),
    ),
    layoutBuilder: (current, previous) =>
        Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
    child: child,
  );
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
                    child: MotionCard(
                      cardId: cards[i].id,
                      child: PlayingCard(cards[i], width: width, shadow: false, dimmed: cards[i] == player.bustCard),
                    ),
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
    final view = ref.watch(tableViewProvider)!;
    final flipThree = view.flipThrees.where((f) => f.remaining > 0).lastOrNull;
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
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      _Stage(cardWidth: cardWidth),
                      const Positioned(top: -6, child: _DeckNews()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatusLine(room: room, view: view),
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

/// The last card revealed, with whose it is underneath. It plays its effect when playback reveals
/// it (PRD §9.3); in the screen gallery and tests it simply shows the room's last card.
class _Stage extends ConsumerWidget {
  const _Stage({required this.cardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shot = ref.watch(tableDirectorProvider.select((s) => s.stage));
    final myId = ref.watch(roomProvider.select((s) => s.playerId));
    // A record, so this rebuilds only when the card, its owner or what it did changes.
    final stage = ref.watch(
      tableViewProvider.select((view) {
        final draw = shot?.draw ?? view?.lastDraw;
        if (draw == null) return null;
        final owner = view!.player(draw.playerId);
        return (
          card: draw.card,
          effect: shot?.effect ?? stageEffectFor(draw, owner),
          mine: draw.playerId == myId,
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
        KeyedSubtree(
          key: TableGeometry.maybeOf(context)?.stageKey,
          child: LastCardStage(
            card: stage?.card,
            effect: effect,
            width: cardWidth,
            stampLabel: stamp,
            play: shot?.play ?? 0,
          ),
        ),
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

/// A short note over the table when the deck changes (PRD §6.3): the discard pile shuffled back in,
/// a second deck joining, or a fresh deck. It shows for its beat, then fades.
class _DeckNews extends StatelessWidget {
  const _DeckNews();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CueEffect(
      matches: (cue) => cue.type == 'reshuffled' || cue.type == 'extraDeckAdded' || cue.type == 'deckReset',
      duration: AppMotion.reshuffle + AppMotion.medium,
      builder: (context, t, cue, _) {
        if (t >= 1 || cue == null) return const SizedBox.shrink();
        final label = switch (cue.type) {
          'reshuffled' => l10n.deckReshuffled,
          'extraDeckAdded' => l10n.deckExtra,
          _ => l10n.deckFresh,
        };
        final appear = Curves.easeOutBack.transform(math.min(1, t * 4));
        final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
        return IgnorePointer(
          child: Transform.scale(
            scale: 0.85 + 0.15 * appear,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 14, 6),
              decoration: BoxDecoration(
                color: AppColors.panel.withValues(alpha: 0.95 * fade),
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.7 * fade)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: t * math.pi * 2,
                    child: Icon(Icons.autorenew_rounded, size: 16, color: AppColors.gold.withValues(alpha: fade)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppText.label.copyWith(color: AppColors.onTable.withValues(alpha: fade)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.room, required this.view});

  final RoomState room;
  final RoomView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final decision = view.decision;
    final owner = view.player(decision?.playerId);
    final mine = decision != null && decision.playerId == room.playerId;
    final turnPlayer = view.player(view.turnPlayerId);
    // Hard Mode: a forced player draws with no prompt (Rules §11.1).
    final forced = decision == null && view.phase == Phase.turns && (turnPlayer?.forced ?? false);

    final String text;
    if (forced) {
      text = turnPlayer!.id == room.playerId
          ? l10n.forcedDrawMine
          : l10n.forcedDrawOf(isolate(displayName(l10n, turnPlayer)));
    } else if (decision == null && view.phase == Phase.turns && turnPlayer != null) {
      // Between a move and the next prompt: it's still this player's turn.
      text = turnPlayer.id == room.playerId ? l10n.yourTurn : l10n.turnOf(isolate(displayName(l10n, turnPlayer)));
    } else if (decision == null) {
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
    if (forced) {
      leading = const Icon(Icons.whatshot_rounded, size: 20, color: AppColors.flipThree);
    } else if (decision == null || (view.tutorial && (owner?.bot ?? false))) {
      leading = spinner;
    } else if (view.tutorial) {
      leading = const Icon(Icons.touch_app_rounded, size: 20, color: AppColors.gold);
    } else {
      leading = TimerRing(
        deadline: decision.deadline,
        totalMs: decision.kind == DecisionKind.hitOrStay ? _hitOrStayMs : _chooseMs,
        clockOffsetMs: room.clockOffsetMs,
        // The last seconds of your own turn tick, with a light haptic (PRD §6.3–6.4).
        onSecond: mine
            ? (_) {
                final feedback = ref.read(gameFeedbackProvider);
                feedback.play(Sfx.tick);
                feedback.buzz(Buzz.tick);
              }
            : null,
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
    final view = ref.watch(tableViewProvider)!;
    final me = view.player(room.playerId);
    if (me == null) return const SizedBox.shrink();
    final controller = ref.read(roomProvider.notifier);
    final decision = ref.watch(myDecisionProvider);
    final pending = room.pendingDecisionId != null && room.pendingDecisionId == room.view?.decision?.id;
    final choosing = decision != null && decision.kind != DecisionKind.hitOrStay;

    final panel = Container(
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
                    _FlipThreeBadge(view: view, playerId: me.id, size: 24),
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
                : CueEffect(
                    key: const ValueKey('hit-stay'),
                    // Your turn: the buttons give a little bounce as they light up (PRD §6.3).
                    matches: (cue) =>
                        cue.type == 'decisionRequested' &&
                        (cue.event.data['decision'] as Map<String, dynamic>)['playerId'] == room.playerId,
                    duration: AppMotion.medium,
                    builder: (context, t, cue, child) =>
                        Transform.scale(scale: t >= 1 ? 1 : 1 + 0.045 * math.sin(math.pi * t), child: child),
                    child: Row(
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
          ),
        ],
      ),
    );
    // A bust shakes and flashes the panel; a Freeze frosts it (PRD §6.3).
    return _SeatEffects(
      playerId: me.id,
      frozen: me.status == PlayerStatus.frozen,
      radius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      child: panel,
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
    final stayed = me.status == PlayerStatus.stayed;
    final toStart = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Up to 7 numbers (8 with the duplicate that busted) must fit in one row.
        final slots = numbers.length < 5 ? 5 : numbers.length;
        final width = ((constraints.maxWidth - (slots - 1) * 8) / slots).clamp(30.0, 64.0);
        Widget card(GameCard c) => MotionCard(
          key: ValueKey(c.id),
          cardId: c.id,
          child: c == me.bustCard
              ? DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width * AppRadii.cardFraction),
                    border: Border.all(color: AppColors.danger, width: 3),
                  ),
                  child: PlayingCard(c, width: width),
                )
              : PlayingCard(c, width: width, dimmed: busted),
        );
        return Column(
          children: [
            if (extras.isNotEmpty) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final c in extras)
                      MotionCard(key: ValueKey(c.id), cardId: c.id, child: PlayingCard(c, width: 36)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: width * PlayingCard.aspectRatio,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                // Staying banks the row: the cards slide together. A bust tilts them (PRD §6.3).
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: stayed ? 1 : 0),
                  duration: AppMotion.stay,
                  curve: AppMotion.standard,
                  builder: (context, bank, _) => TweenAnimationBuilder<double>(
                    tween: Tween(end: busted ? 1 : 0),
                    duration: AppMotion.bust,
                    curve: AppMotion.spring,
                    builder: (context, tilt, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < numbers.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..translateByDouble(toStart * i * (width + 8) * 0.3 * bank, 4 * tilt, 0, 1)
                              ..rotateZ(tilt * (i.isEven ? -0.06 : 0.05)),
                            child: card(numbers[i]),
                          ),
                        ],
                        if (numbers.isEmpty) _EmptySlot(width: width),
                      ],
                    ),
                  ),
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
/// The break between rounds (PRD §6.3, §8.4.1): round scores count up, then totals, then the
/// leaderboard re-sorts. Rows move by transform only. A tie-break round doesn't change totals, so
/// it ranks by that round's score instead.
class _RoundSummary extends ConsumerStatefulWidget {
  const _RoundSummary();

  @override
  ConsumerState<_RoundSummary> createState() => _RoundSummaryState();
}

class _RoundSummaryState extends ConsumerState<_RoundSummary> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.roundEnd);
  late final _roundCount = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
  );
  late final _totalCount = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
  );
  late final _move = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.7, 1, curve: Curves.easeInOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.value > 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _roundCount.dispose();
    _totalCount.dispose();
    _move.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = ref.watch(tableViewProvider)!;
    final tiebreakRound = view.scoredTiebreakRound != null;
    final scored = view.players.where((p) => view.roundPlayerIds.contains(p.id)).toList();
    int before(PlayerView p) => tiebreakRound ? p.total : p.total - p.roundScore;
    int rank(PlayerView p) => tiebreakRound ? p.roundScore : p.total;
    final after = [...scored]..sort((a, b) => rank(b).compareTo(rank(a)));
    final previous = tiebreakRound ? after : ([...scored]..sort((a, b) => before(b).compareTo(before(a))));
    final rowHeight = MediaQuery.textScalerOf(context).scale(24) + 22;
    final roundCount = _roundCount;
    final totalCount = _totalCount;
    final move = _move;

    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tiebreakRound ? l10n.tiebreakLabel(view.scoredTiebreakRound!) : l10n.roundScoresTitle(view.round),
            style: AppText.title.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: rowHeight * after.length,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                children: [
                  for (var i = 0; i < after.length; i++)
                    Positioned(
                      top: i * rowHeight,
                      left: 0,
                      right: 0,
                      height: rowHeight,
                      child: Transform.translate(
                        offset: Offset(0, (previous.indexOf(after[i]) - i) * rowHeight * (1 - move.value)),
                        child: _SummaryRow(
                          player: after[i],
                          isMe: after[i].id == room.playerId,
                          roundShown: (after[i].roundScore * roundCount.value).round(),
                          totalShown: (before(after[i]) + (after[i].total - before(after[i])) * totalCount.value)
                              .round(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (view.tiebreak != null && view.tiebreak!.roundNo != view.scoredTiebreakRound) ...[
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.player, required this.isMe, required this.roundShown, required this.totalShown});

  final PlayerView player;
  final bool isMe;
  final int roundShown;
  final int totalShown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busted = player.status == PlayerStatus.busted;
    return Row(
      children: [
        PlayerAvatar(nickname: displayName(l10n, player), size: 30, highlight: isMe, bot: player.bot),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isMe ? l10n.you : displayName(l10n, player),
            style: AppText.body.copyWith(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (player.seventhCard)
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 6),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 18),
          ),
        Text(
          busted && player.roundScore == 0 ? l10n.stageBust : (roundShown >= 0 ? '+$roundShown' : '$roundShown'),
          textDirection: busted && player.roundScore == 0 ? null : TextDirection.ltr,
          style: AppText.heading.copyWith(color: busted ? AppColors.danger : AppColors.gold),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '$totalShown',
            textAlign: TextAlign.end,
            textDirection: TextDirection.ltr,
            style: AppText.label.copyWith(color: AppColors.onTable),
          ),
        ),
      ],
    );
  }
}

/// The Seventh Card (PRD §6.3): confetti, a big «السابعة!», who got it, and the +15 bonus.
class _SeventhCelebration extends ConsumerWidget {
  const _SeventhCelebration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return CueEffect(
      matches: (cue) => cue.type == 'seventhCard',
      duration: AppMotion.seventhCard,
      builder: (context, t, cue, _) {
        if (t >= 1 || cue == null) return const SizedBox.shrink();
        final view = ref.read(tableViewProvider);
        final player = view?.player(cue.playerId);
        final name = cue.playerId == ref.read(roomProvider).playerId ? l10n.you : displayName(l10n, player);
        final pop = Curves.easeOutBack.transform(math.min(1, t / 0.25));
        final chip = Curves.easeOutBack.transform(((t - 0.2) / 0.25).clamp(0.0, 1.0));
        final fade = t > 0.82 ? (1 - t) / 0.18 : 1.0;
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: AppColors.scrim.withValues(alpha: 0.55 * fade)),
              ),
              Positioned.fill(
                child: ConfettiBurst(key: ValueKey(cue.seq), duration: AppMotion.seventhCard),
              ),
              // Above the middle of the table, so the card that did it stays in view below.
              Align(
                alignment: const Alignment(0, -0.38),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.6 + 0.4 * pop,
                      child: Text(
                        l10n.seventhCard,
                        style: AppText.display.copyWith(
                          fontSize: 46,
                          color: AppColors.gold.withValues(alpha: fade),
                          shadows: [Shadow(color: AppColors.shadow.withValues(alpha: 0.6 * fade), blurRadius: 18)],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Transform.scale(
                      scale: chip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: fade),
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.heading.copyWith(color: AppColors.onGold.withValues(alpha: fade)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '+15',
                              textDirection: TextDirection.ltr,
                              style: AppText.numeral(22, AppColors.onGold.withValues(alpha: fade)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
