import '../net/protocol.dart';

/// What the last card did, which picks its effect (PRD §6.2–6.3).
enum StageEffect { plain, bust, saved, seventh, freeze, drawThree, secondChance, modifier }

/// Reads the effect off the view: it shows what the server decided, it never decides it.
StageEffect stageEffectFor(LastDraw draw, PlayerView? owner) {
  final card = draw.card;
  switch (card.kind) {
    case CardKind.freeze:
      return StageEffect.freeze;
    case CardKind.drawThree:
      return StageEffect.drawThree;
    case CardKind.secondChance:
      return StageEffect.secondChance;
    case CardKind.plus || CardKind.x2:
      return StageEffect.modifier;
    case CardKind.number:
      if (owner == null) return StageEffect.plain;
      if (owner.bustCard == card) return StageEffect.bust;
      final inRow = owner.row.contains(card);
      if (inRow && owner.seventhCard && owner.row.last == card) return StageEffect.seventh;
      // A number that's neither in the row nor the bust card was a duplicate a Second Chance saved.
      return inRow ? StageEffect.plain : StageEffect.saved;
  }
}
