import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../net/protocol.dart';
import '../state/stage_effect.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import 'playing_card.dart';

export '../state/stage_effect.dart';

/// The last card revealed, big in the middle of the table, with a one-off effect when it arrives:
/// it flips in, and special cards add a burst (PRD §6.3). Only transforms and opacity animate, the
/// controller stops when the effect ends, and "reduce motion" swaps it all for a short fade.
class LastCardStage extends StatefulWidget {
  const LastCardStage({
    super.key,
    required this.card,
    required this.effect,
    required this.width,
    required this.stampLabel,
    this.play = 0,
    this.debugProgress,
  });

  /// Null before the first card of the round: a face-down card stands in.
  final GameCard? card;
  final StageEffect effect;
  final double width;

  /// The word stamped on the card for a bust, a save or the Seventh Card, in the player's language.
  final String? stampLabel;

  /// Changes when playback reveals a card here (PRD §9.3). The effect plays only then, never when
  /// the screen simply catches up to a card that's already on the table.
  final int play;

  /// For the screen gallery: shows the effect frozen at this point (0–1) instead of playing it.
  final double? debugProgress;

  @override
  State<LastCardStage> createState() => _LastCardStageState();
}

class _LastCardStageState extends State<LastCardStage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1);
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller.duration = _durationFor(widget.effect);
    if (widget.debugProgress != null) _controller.value = widget.debugProgress!;
  }

  @override
  void didUpdateWidget(LastCardStage old) {
    super.didUpdateWidget(old);
    if (widget.debugProgress != null) {
      _controller.value = widget.debugProgress!;
      return;
    }
    // Playback revealed a card while this screen was showing: play its effect. (A card shown after
    // joining, reconnecting or skipping ahead appears without one.)
    if (widget.card != null && old.play != widget.play) {
      _reduced = MediaQuery.disableAnimationsOf(context);
      _controller.duration = _reduced ? AppMotion.fast : _durationFor(widget.effect);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static Duration _durationFor(StageEffect effect) => switch (effect) {
    StageEffect.plain => AppMotion.reveal,
    StageEffect.bust => AppMotion.stageBust,
    StageEffect.seventh => AppMotion.stageSeventh,
    _ => AppMotion.stageSpecial,
  };

  int get _totalMs => _controller.duration!.inMilliseconds;

  /// 0 → 1 between two moments of the effect, in milliseconds.
  Animation<double> _between(int fromMs, int toMs, {Curve curve = Curves.linear}) {
    final total = _totalMs;
    final begin = (fromMs / total).clamp(0.0, 1.0);
    final end = (toMs / total).clamp(begin, 1.0);
    return _controller.drive(CurveTween(curve: Interval(begin, end, curve: curve)));
  }

  /// Fades in, holds, then fades out.
  Animation<double> _pulse(int fromMs, int peakMs, int fadeFromMs, int toMs) {
    final total = _totalMs;
    double w(int ms) => math.max(ms, 1) / total;
    return _controller.drive(
      TweenSequence<double>([
        if (fromMs > 0) TweenSequenceItem(tween: ConstantTween(0), weight: w(fromMs)),
        TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: w(peakMs - fromMs)),
        TweenSequenceItem(tween: ConstantTween(1), weight: w(fadeFromMs - peakMs)),
        TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: w(toMs - fadeFromMs)),
        if (toMs < total) TweenSequenceItem(tween: ConstantTween(0), weight: w(total - toMs)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final card = widget.card;
    final face = card == null ? PlayingCard.back(width: width) : PlayingCard(card, width: width);
    final back = PlayingCard.back(width: width);
    final reduced = _reduced && widget.debugProgress == null;
    final effect = widget.effect;
    final flipEnd = math.min(AppMotion.reveal.inMilliseconds, _totalMs);

    final layers = <Widget>[];
    if (!reduced && card != null) {
      final tint = _tint(effect);
      if (tint != null) layers.add(_ring(tint, width, flipEnd - 20, _totalMs - 60));
      if (effect == StageEffect.seventh) layers.add(_ring(AppColors.gold, width, flipEnd + 180, _totalMs));
      if (effect == StageEffect.flipThree) layers.add(_ghosts(width, flipEnd));
    }

    // The card itself: a 3D flip whose face swaps in at 90° (PRD §6.3), then a shake for a bust.
    final shake = _between(flipEnd, flipEnd + 340);
    layers.add(
      reduced
          ? FadeTransition(opacity: _controller, child: face)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = card == null ? 1.0 : (_controller.value * _totalMs / flipEnd).clamp(0.0, 1.0);
                final eased = AppMotion.enter.transform(t);
                final angle = (1 - eased) * math.pi; // π → 0: the back turns away, then the face turns in
                final showFace = angle <= math.pi / 2;
                var dx = 0.0;
                if (effect == StageEffect.bust && shake.value > 0 && shake.value < 1) {
                  dx = math.sin(shake.value * math.pi * 6) * width * 0.07 * (1 - shake.value);
                }
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..translateByDouble(dx, -10 * (1 - eased), 0, 1)
                  ..rotateY(showFace ? angle : angle - math.pi)
                  ..scaleByDouble(0.9 + 0.1 * eased, 0.9 + 0.1 * eased, 1, 1);
                return Transform(alignment: Alignment.center, transform: matrix, child: showFace ? face : back);
              },
            ),
    );

    if (!reduced && card != null) {
      final burst = _burstFor(effect, width, flipEnd);
      if (burst != null) layers.add(burst);
    }
    final stamp = widget.stampLabel;
    if (stamp != null && card != null) layers.add(_stamp(stamp, effect, width, flipEnd, reduced));

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: width * PlayingCard.aspectRatio,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: layers),
      ),
    );
  }

  static Color? _tint(StageEffect effect) => switch (effect) {
    StageEffect.plain => null,
    StageEffect.bust => AppColors.danger,
    StageEffect.saved || StageEffect.secondChance => AppColors.secondChance,
    StageEffect.seventh || StageEffect.modifier => AppColors.gold,
    StageEffect.freeze => AppColors.freeze,
    StageEffect.flipThree => AppColors.flipThree,
  };

  /// A ring that grows out from behind the card and fades.
  Widget _ring(Color color, double width, int fromMs, int toMs) {
    final grow = _between(fromMs, toMs, curve: AppMotion.enter);
    return Positioned.fill(
      child: OverflowBox(
        maxWidth: width * 2,
        maxHeight: width * 2,
        child: FadeTransition(
          opacity: grow.drive(Tween(begin: 0.9, end: 0.0)),
          child: ScaleTransition(
            scale: grow.drive(Tween(begin: 0.55, end: 1.25)),
            child: Container(
              width: width * 1.6,
              height: width * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Flip Three: three face-down cards fan out from behind it, then fade.
  Widget _ghosts(double width, int flipEnd) {
    final fan = _between(flipEnd - 40, flipEnd + 300, curve: AppMotion.spring);
    final fade = _pulse(flipEnd - 40, flipEnd + 60, _totalMs - 260, _totalMs);
    final ghost = PlayingCard.back(width: width * 0.86, shadow: false, emblem: false);
    return FadeTransition(
      opacity: fade,
      child: AnimatedBuilder(
        animation: fan,
        builder: (context, child) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (final side in const [-1.0, 0.0, 1.0])
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..translateByDouble(
                    side * width * 0.62 * fan.value,
                    -width * 0.12 * fan.value * (side == 0 ? 1.6 : 1),
                    0,
                    1,
                  )
                  ..rotateZ(side * 0.32 * fan.value),
                child: child,
              ),
          ],
        ),
        child: ghost,
      ),
    );
  }

  /// Snowflakes, sparkles or a shield bursting out from the card.
  Widget? _burstFor(StageEffect effect, double width, int flipEnd) {
    final (IconData icon, Color color, int count, double spin) = switch (effect) {
      StageEffect.freeze => (Icons.ac_unit_rounded, AppColors.freeze, 8, 1.4),
      StageEffect.modifier => (Icons.auto_awesome_rounded, AppColors.gold, 8, 0.6),
      StageEffect.seventh => (Icons.auto_awesome_rounded, AppColors.gold, 12, 0.8),
      StageEffect.secondChance || StageEffect.saved => (Icons.shield_rounded, AppColors.secondChance, 6, 0.0),
      _ => (Icons.circle, Colors.transparent, 0, 0.0),
    };
    if (count == 0) return null;
    final move = _between(flipEnd - 30, _totalMs, curve: Curves.easeOutQuart);
    final fade = _pulse(flipEnd - 30, flipEnd + 60, _totalMs - 300, _totalMs);
    final size = width * (effect == StageEffect.seventh ? 0.2 : 0.22);
    final particle = Icon(icon, size: size, color: color);
    final radius = width * (effect == StageEffect.seventh ? 1.15 : 0.95);
    return IgnorePointer(
      child: FadeTransition(
        opacity: fade,
        child: AnimatedBuilder(
          animation: move,
          builder: (context, child) => Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Transform(
                  alignment: Alignment.center,
                  transform: () {
                    final angle = (i / count) * math.pi * 2 - math.pi / 2 + (i.isEven ? 0 : 0.18);
                    final reach = radius * (i.isEven ? 1 : 0.78) * move.value;
                    return Matrix4.identity()
                      ..translateByDouble(math.cos(angle) * reach, math.sin(angle) * reach * 1.15, 0, 1)
                      ..rotateZ(spin * move.value * (i.isEven ? 1 : -1))
                      ..scaleByDouble(0.5 + 0.5 * move.value, 0.5 + 0.5 * move.value, 1, 1);
                  }(),
                  child: child,
                ),
            ],
          ),
          child: particle,
        ),
      ),
    );
  }

  /// "Bust!", "Saved!" or "Seventh Card!" stamped across the bottom of the card. It stays.
  Widget _stamp(String label, StageEffect effect, double width, int flipEnd, bool reduced) {
    final color = switch (effect) {
      StageEffect.bust => AppColors.danger,
      StageEffect.saved => AppColors.secondChance,
      _ => AppColors.gold,
    };
    final box = Transform.rotate(
      angle: -0.16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: width * 0.02),
        decoration: BoxDecoration(
          color: AppColors.table.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(width * 0.09),
          border: Border.all(color: color, width: math.max(2, width * 0.035)),
        ),
        child: Text(label, maxLines: 1, style: AppText.numeral(width * 0.2, color).copyWith(height: 1.35)),
      ),
    );
    final positioned = Align(
      alignment: const Alignment(0, 0.62),
      child: SizedBox(
        width: width * 1.5,
        child: FittedBox(fit: BoxFit.scaleDown, child: box),
      ),
    );
    if (reduced) return IgnorePointer(child: positioned);
    final pop = _between(flipEnd, flipEnd + 260, curve: AppMotion.spring);
    return IgnorePointer(
      child: FadeTransition(
        opacity: _between(flipEnd, flipEnd + 120),
        child: ScaleTransition(scale: pop.drive(Tween(begin: 1.8, end: 1.0)), child: positioned),
      ),
    );
  }
}
