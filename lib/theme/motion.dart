import 'package:flutter/animation.dart';

/// Animation timings and curves (PRD §6.3). Every animation uses these, never literal durations.
abstract final class AppMotion {
  // Interface
  static const press = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const screen = Duration(milliseconds: 320);

  // Game moments (PRD §6.3 table)
  static const deal = Duration(milliseconds: 350);
  static const reveal = Duration(milliseconds: 300);
  static const flipThreeGap = Duration(milliseconds: 500);
  static const secondChance = Duration(milliseconds: 450);
  static const bust = Duration(milliseconds: 600);
  static const freeze = Duration(milliseconds: 500);
  static const stay = Duration(milliseconds: 300);
  static const seventhCard = Duration(milliseconds: 1500);
  static const roundEnd = Duration(milliseconds: 1200);
  static const reshuffle = Duration(milliseconds: 600);
  static const extraDeck = Duration(milliseconds: 600);

  // Beats: how long playback spends on each event before the next (PRD §9.3). A card's flight to
  // its row overlaps the next card's flip, so a deal keeps moving.
  static const beatDeal = Duration(milliseconds: 420);
  static const beatHit = Duration(milliseconds: 480);
  static const beatFlipThree = Duration(milliseconds: 600);
  static const beatDuplicate = Duration(milliseconds: 600);
  static const beatModifier = Duration(milliseconds: 750);
  static const beatAction = Duration(milliseconds: 950);
  static const beatTarget = Duration(milliseconds: 450);
  static const beatShort = Duration(milliseconds: 350);
  static const beatClear = Duration(milliseconds: 350);
  static const beatFinalRound = Duration(milliseconds: 1800);

  /// A tie-break round's introduction, before its deal (Rules §10.2).
  static const beatTiebreak = Duration(milliseconds: 1900);

  /// A card flying from the middle of the table to its row.
  static const flight = Duration(milliseconds: 380);

  // The last card in the middle of the table (PRD §6.2): the flip, then the card's own effect.
  static const stageSpecial = Duration(milliseconds: 950);
  static const stageBust = Duration(milliseconds: 850);
  static const stageSeventh = Duration(milliseconds: 1200);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;
  static const spring = Curves.easeOutBack;

  /// Scale of a pressed control.
  static const pressedScale = 0.97;
}
