import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/state/nickname_rules.dart';

void main() {
  group('nicknames (PRD §4.1)', () {
    test('accepts Arabic and Latin letters, digits and spaces, up to 16 characters', () {
      for (final name in ['Ali', 'عبدالله', 'عبد الله', 'Sara 2', 'نورة٢', 'José', 'a' * 16]) {
        expect(NicknameRules.isValid(name), isTrue, reason: name);
      }
    });

    test('refuses empty, too long, emoji and control characters', () {
      for (final name in ['', '   ', 'a' * 17, '😀', 'Bad\u0007Name', 'a<b>']) {
        expect(NicknameRules.isValid(name), isFalse, reason: name);
      }
    });

    test('trims and collapses spaces', () {
      expect(NicknameRules.clean('  عبد   الله  '), 'عبد الله');
    });
  });

  group('room codes (PRD R-1)', () {
    test('upper-cases and drops characters that can never be in a code', () {
      expect(RoomCodeRules.clean('k7q2m'), 'K7Q2M');
      expect(RoomCodeRules.clean('k-7 q2m9x'), 'K7Q2M');
      expect(RoomCodeRules.clean('O0I1L'), '', reason: 'look-alikes are not in the alphabet');
    });

    test('a valid code is exactly 5 characters from the alphabet', () {
      expect(RoomCodeRules.isValid('K7Q2M'), isTrue);
      expect(RoomCodeRules.isValid('K7Q2'), isFalse);
      expect(RoomCodeRules.isValid('K7Q2O'), isFalse);
    });
  });
}
