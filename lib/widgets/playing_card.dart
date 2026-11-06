import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../net/protocol.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// A card face, built in code so it's sharp at any size (PRD §6.1). Card faces are always
/// left-to-right and look the same in both languages (PRD §6.6).
///
/// - Number cards: white with a bold band in the number's color (by how many copies it has).
/// - Modifiers (+N, x2): cut corners, so they never read as number cards.
/// - Actions: a dark card framed in the action's color, with an icon.
class PlayingCard extends StatelessWidget {
  const PlayingCard(this.card, {super.key, this.width = 64, this.dimmed = false, this.shadow = true}) : emblem = true;

  /// A face-down card.
  const PlayingCard.back({super.key, this.width = 64, this.shadow = true, this.emblem = true})
    : card = null,
      dimmed = false;

  final GameCard? card;
  final double width;
  final bool dimmed;
  final bool shadow;

  /// Whether a face-down card shows the gold 7.
  final bool emblem;

  static const aspectRatio = 1.4;

  double get height => width * aspectRatio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = this.card;
    final Widget face = switch (card?.kind) {
      null => _Back(width: width, shadow: shadow, emblem: emblem),
      CardKind.number => _NumberFace(value: card!.value, width: width, shadow: shadow),
      CardKind.plus || CardKind.x2 => _ModifierFace(card: card!, width: width, shadow: shadow),
      _ => _ActionFace(kind: card!.kind, width: width, shadow: shadow),
    };
    return Semantics(
      label: _label(l10n, card),
      container: true,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: width,
            height: height,
            child: dimmed ? Opacity(opacity: 0.45, child: face) : face,
          ),
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, GameCard? card) => switch (card?.kind) {
    null => l10n.cardBack,
    CardKind.number => l10n.cardNumber(card!.value),
    CardKind.plus => l10n.cardPlus(card!.value),
    CardKind.x2 => l10n.cardTimesTwo,
    CardKind.freeze => l10n.cardFreeze,
    CardKind.drawThree => l10n.cardDrawThree,
    CardKind.secondChance => l10n.cardSecondChance,
  };
}

List<BoxShadow> _shadowFor(double width, bool on) =>
    on ? [BoxShadow(color: AppColors.shadow, blurRadius: width * 0.14, offset: Offset(0, width * 0.06))] : const [];

class _NumberFace extends StatelessWidget {
  const _NumberFace({required this.value, required this.width, required this.shadow});

  final int value;
  final double width;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * AppRadii.cardFraction);
    final size = value >= 10 ? width * 0.52 : width * 0.64;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: radius,
        border: Border.all(color: AppColors.cardEdge),
        boxShadow: _shadowFor(width, shadow),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: width * PlayingCard.aspectRatio * 0.2,
              child: ColoredBox(color: AppColors.numberBands[value]),
            ),
            Align(
              alignment: const Alignment(0, -0.22),
              child: Text('$value', style: AppText.numeral(size, AppColors.numberInks[value])),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifierFace extends StatelessWidget {
  const _ModifierFace({required this.card, required this.width, required this.shadow});

  final GameCard card;
  final double width;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final label = card.kind == CardKind.x2 ? '×2' : '+${card.value}';
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.modifierFace,
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(width * 0.2)),
        shadows: _shadowFor(width, shadow),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.07),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(width * 0.14),
              side: BorderSide(color: AppColors.modifierInk.withValues(alpha: 0.35)),
            ),
          ),
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                child: Text(label, style: AppText.numeral(width * 0.36, AppColors.modifierInk)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionFace extends StatelessWidget {
  const _ActionFace({required this.kind, required this.width, required this.shadow});

  final CardKind kind;
  final double width;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final tint = switch (kind) {
      CardKind.freeze => AppColors.freeze,
      CardKind.drawThree => AppColors.drawThree,
      _ => AppColors.secondChance,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.actionFace,
        borderRadius: BorderRadius.circular(width * AppRadii.cardFraction),
        border: Border.all(color: tint, width: math.max(1.5, width * 0.045)),
        boxShadow: _shadowFor(width, shadow),
      ),
      child: Center(
        child: Container(
          width: width * 0.66,
          height: width * 0.66,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.16)),
          child: switch (kind) {
            CardKind.drawThree => CustomPaint(
              painter: _CircularArrowPainter(tint, math.max(1.2, width * 0.05)),
              child: Center(child: Text('3', style: AppText.numeral(width * 0.3, tint))),
            ),
            CardKind.freeze => Icon(Icons.ac_unit_rounded, color: tint, size: width * 0.46),
            _ => Icon(Icons.shield_rounded, color: tint, size: width * 0.46),
          },
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.width, required this.shadow, required this.emblem});

  final double width;
  final bool shadow;
  final bool emblem;

  @override
  Widget build(BuildContext context) {
    final radius = width * AppRadii.cardFraction;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBack,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBackInk.withValues(alpha: 0.5), width: 1.2),
        boxShadow: _shadowFor(width, shadow),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.08),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius * 0.6),
            border: Border.all(color: AppColors.cardBackInk.withValues(alpha: 0.35)),
          ),
          child: emblem && width >= 32
              ? Center(child: Text('7', style: AppText.numeral(width * 0.42, AppColors.cardBackInk)))
              : null,
        ),
      ),
    );
  }
}

/// A circular arrow (about 300°) with an arrowhead, around the Draw Three card's 3.
class _CircularArrowPainter extends CustomPainter {
  _CircularArrowPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth * 1.6;
    const start = -math.pi / 2 + 0.5;
    const sweep = math.pi * 2 - 1.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
    const end = start + sweep;
    final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
    final tangent = Offset(-math.sin(end), math.cos(end));
    final normal = Offset(math.cos(end), math.sin(end));
    final head = strokeWidth * 2.2;
    final path = Path()
      ..moveTo((tip + tangent * head).dx, (tip + tangent * head).dy)
      ..lineTo((tip + normal * head * 0.9).dx, (tip + normal * head * 0.9).dy)
      ..lineTo((tip - normal * head * 0.9).dx, (tip - normal * head * 0.9).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CircularArrowPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
