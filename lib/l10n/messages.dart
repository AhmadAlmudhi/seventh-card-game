import '../net/protocol.dart';
import 'app_localizations.dart';

/// The player-facing message for a server or app error code (PRD §4.3, §6.6). The server never
/// sends display text.
String errorMessage(AppLocalizations l10n, String code) => switch (code) {
      'ROOM_NOT_FOUND' => l10n.errorRoomNotFound,
      'ROOM_FULL' => l10n.errorRoomFull,
      'GAME_STARTED' => l10n.errorGameStarted,
      'ROOM_BUSY' => l10n.errorRoomBusy,
      'NICKNAME_TAKEN' => l10n.errorNicknameTaken,
      'INVALID_NICKNAME' => l10n.nicknameInvalid,
      'REMOVED' => l10n.errorRemoved,
      'SEAT_LOST' => l10n.errorSeatLost,
      'CONNECTION_LOST' => l10n.errorConnectionLost,
      'SERVERS_BUSY' => l10n.errorServersBusy,
      'NETWORK' => l10n.errorNetwork,
      'GAME_ABANDONED' => l10n.errorGameAbandoned,
      'NOT_HOST' => l10n.errorNotHost,
      _ => l10n.errorGeneric,
    };

/// A list of names joined the way each language expects ("Ali, Sara" / «علي، سارة»).
String joinNames(AppLocalizations l10n, Iterable<String> names) =>
    names.map((n) => '\u2068$n\u2069').join(l10n.localeName == 'ar' ? '، ' : ', ');

/// A player's name as shown. The tutorial's bot is named in the player's language (PRD §4.9).
String displayName(AppLocalizations l10n, PlayerView? player) =>
    player == null ? '' : (player.bot ? l10n.botName : player.nickname);

/// Wraps a nickname in Unicode isolation so mixed Arabic and Latin names don't jumble the text
/// around them (PRD §6.6).
String isolate(String name) => '\u2068$name\u2069';
