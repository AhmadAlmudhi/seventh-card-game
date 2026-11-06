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

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;
  static const spring = Curves.easeOutBack;

  /// Scale of a pressed control.
  static const pressedScale = 0.97;
}
