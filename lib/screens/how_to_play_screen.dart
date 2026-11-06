import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../net/protocol.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/last_card_stage.dart';
import '../widgets/playing_card.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';

/// How to play (PRD §4.8): one scrolling screen, seven short sections, real cards as examples.
/// It summarizes game_rules.md; keep the two in sync.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static GameCard _n(int value) => GameCard(id: 'how-$value', kind: CardKind.number, value: value);
  static const _plus4 = GameCard(id: 'how-p4', kind: CardKind.plus, value: 4);
  static const _x2 = GameCard(id: 'how-x2', kind: CardKind.x2);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          bottom: false,
          child: ContentWidth(
            child: Column(
              children: [
                SimpleTopBar(title: l10n.howToPlay),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.sm,
                      AppSpacing.screen,
                      AppSpacing.xxl,
                    ),
                    children: [
                      _Section(icon: Icons.emoji_events_rounded, title: l10n.howGoalTitle, body: l10n.howGoalBody),
                      _Section(
                        icon: Icons.touch_app_rounded,
                        title: l10n.howTurnTitle,
                        body: l10n.howTurnBody,
                        cards: [_n(3), _n(8), _n(11)],
                      ),
                      _Section(
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.danger,
                        title: l10n.howBustTitle,
                        body: l10n.howBustBody,
                        cards: [_n(7), _n(2), _n(7)],
                        lastEffect: StageEffect.bust,
                      ),
                      _Section(
                        icon: Icons.auto_awesome_rounded,
                        title: l10n.howSeventhTitle,
                        body: l10n.howSeventhBody,
                        cards: [
                          for (final v in const [0, 2, 4, 5, 7, 9, 12]) _n(v),
                        ],
                        cardWidth: 40,
                        lastEffect: StageEffect.seventh,
                      ),
                      _Section(
                        icon: Icons.style_rounded,
                        title: l10n.howSpecialTitle,
                        children: [
                          _CardLine(
                            card: const GameCard(id: 'how-fz', kind: CardKind.freeze),
                            text: l10n.howFreeze,
                          ),
                          _CardLine(
                            card: const GameCard(id: 'how-f3', kind: CardKind.flipThree),
                            text: l10n.howFlipThree,
                          ),
                          _CardLine(
                            card: const GameCard(id: 'how-sc', kind: CardKind.secondChance),
                            text: l10n.howSecondChance,
                          ),
                          _CardLine(card: _plus4, text: l10n.howPlus),
                          _CardLine(card: _x2, text: l10n.howTimesTwo),
                        ],
                      ),
                      _Section(
                        icon: Icons.calculate_rounded,
                        title: l10n.howScoringTitle,
                        body: l10n.howScoringBody,
                        cards: [_n(11), _n(5), _n(12), _x2, _plus4],
                        footer: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '(11 + 5 + 12) × 2 + 4 = 60',
                            style: AppText.heading.copyWith(color: AppColors.gold),
                          ),
                        ),
                      ),
                      _Section(icon: Icons.whatshot_rounded, title: l10n.howHardTitle, body: l10n.howHardBody),
                      _Section(
                        icon: Icons.palette_rounded,
                        title: null,
                        body: l10n.howColorsNote,
                        cards: [
                          for (final v in const [0, 3, 6, 9, 12]) _n(v),
                        ],
                        cardWidth: 40,
                      ),
                    ],
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    this.body,
    this.cards = const [],
    this.cardWidth = 52,
    this.lastEffect,
    this.children = const [],
    this.footer,
    this.accent = AppColors.gold,
  });

  final IconData icon;
  final String? title;
  final String? body;
  final List<GameCard> cards;
  final double cardWidth;

  /// What the example's last card shows when it scrolls into view.
  final StageEffect? lastEffect;
  final List<Widget> children;
  final Widget? footer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Panel(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(child: Text(title!, style: AppText.heading)),
                ],
              ),
            if (body != null) ...[
              if (title != null) const SizedBox(height: AppSpacing.sm + 2),
              Text(body!, style: AppText.body.copyWith(fontSize: 15.5)),
            ],
            if (cards.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      // The last card of an example plays its moment once it scrolls into view
                      // (PRD §4.8): the duplicate busts, the seventh number sparkles.
                      i == cards.length - 1 && lastEffect != null
                          ? _PlayWhenVisible(
                              card: cards[i],
                              width: cardWidth,
                              effect: lastEffect!,
                              stamp: switch (lastEffect!) {
                                StageEffect.bust => AppLocalizations.of(context).stageBust,
                                StageEffect.seventh => AppLocalizations.of(context).seventhCard,
                                _ => null,
                              },
                            )
                          : PlayingCard(cards[i], width: cardWidth),
                  ],
                ),
              ),
            ],
            if (footer != null) ...[const SizedBox(height: AppSpacing.md), footer!],
            if (children.isNotEmpty) ...[const SizedBox(height: AppSpacing.sm), ...children],
          ],
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.card, required this.text});

  final GameCard card;
  final String text;

  static StageEffect _effectOf(GameCard card) => switch (card.kind) {
    CardKind.freeze => StageEffect.freeze,
    CardKind.flipThree => StageEffect.flipThree,
    CardKind.secondChance => StageEffect.secondChance,
    _ => StageEffect.modifier,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PlayWhenVisible(card: card, width: 40, effect: _effectOf(card)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 15))),
      ],
    ),
  );
}

/// A card that plays its table effect once, the first time most of it is on screen.
class _PlayWhenVisible extends StatefulWidget {
  const _PlayWhenVisible({required this.card, required this.width, required this.effect, this.stamp});

  final GameCard card;
  final double width;
  final StageEffect effect;
  final String? stamp;

  @override
  State<_PlayWhenVisible> createState() => _PlayWhenVisibleState();
}

class _PlayWhenVisibleState extends State<_PlayWhenVisible> {
  int _play = 0;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _play > 0) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    if (top >= 0 && top + box.size.height * 0.6 <= screen) {
      _position?.removeListener(_check);
      setState(() => _play = 1);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LastCardStage(
    card: widget.card,
    effect: widget.effect,
    width: widget.width,
    stampLabel: _play > 0 ? widget.stamp : null,
    play: _play,
  );
}
