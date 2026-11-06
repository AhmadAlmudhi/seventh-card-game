/// The nickname rules (PRD §4.1), matching the server's check so players see problems before
/// they try to join. The server stays the judge.
abstract final class NicknameRules {
  static const maxLength = 16;

  static final _allowed = RegExp(r'^[\p{Script=Arabic}\p{Script=Latin}\p{M}\p{Nd}ـ ]+$', unicode: true);

  /// The cleaned nickname: trimmed, with runs of whitespace collapsed to one space.
  static String clean(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool isValid(String raw) {
    final nickname = clean(raw);
    final length = nickname.runes.length;
    return length >= 1 && length <= maxLength && _allowed.hasMatch(nickname);
  }
}

/// Room codes (PRD R-1): 5 characters from an alphabet without look-alikes.
abstract final class RoomCodeRules {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 5;

  /// Upper-cases and drops anything outside the alphabet, so typing is forgiving.
  static String clean(String raw) => raw.toUpperCase().split('').where(alphabet.contains).take(length).join();

  static bool isValid(String code) => code.length == length && code.split('').every(alphabet.contains);
}
