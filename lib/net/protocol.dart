/// Messages from the server, mirroring `server/src/protocol.ts` and the engine's public view
/// (PRD §8.5). The app only reads these; it never decides game results (PRD G-2).
library;

enum CardKind { number, plus, x2, freeze, flipThree, secondChance }

class GameCard {
  const GameCard({required this.id, required this.kind, this.value = 0});

  final String id;
  final CardKind kind;

  /// The number for number cards, or the amount for + cards. 0 otherwise.
  final int value;

  bool get isNumber => kind == CardKind.number;
  bool get isAction => kind == CardKind.freeze || kind == CardKind.flipThree || kind == CardKind.secondChance;

  factory GameCard.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    switch (json['kind']) {
      case 'number':
        return GameCard(id: id, kind: CardKind.number, value: json['value'] as int);
      case 'plus':
        return GameCard(id: id, kind: CardKind.plus, value: json['amount'] as int);
      case 'x2':
        return GameCard(id: id, kind: CardKind.x2);
      case 'action':
        final kind = switch (json['action']) {
          'freeze' => CardKind.freeze,
          'flip_three' => CardKind.flipThree,
          _ => CardKind.secondChance,
        };
        return GameCard(id: id, kind: kind);
      default:
        throw FormatException('unknown card kind ${json['kind']}');
    }
  }

  @override
  bool operator ==(Object other) => other is GameCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum PlayerStatus { active, stayed, frozen, busted, left, watching }

class PlayerView {
  const PlayerView({
    required this.id,
    required this.nickname,
    required this.seat,
    required this.total,
    required this.connected,
    required this.status,
    required this.row,
    required this.modifiers,
    required this.secondChance,
    required this.played,
    required this.bustCard,
    required this.seventhCard,
    required this.forced,
    required this.roundScore,
    required this.returned,
    this.bot = false,
  });

  final String id;
  final String nickname;
  final int seat;
  final int total;
  final bool connected;
  final PlayerStatus status;
  final List<GameCard> row;
  final List<GameCard> modifiers;
  final GameCard? secondChance;
  final List<GameCard> played;
  final GameCard? bustCard;
  final bool seventhCard;
  final bool forced;
  final int roundScore;
  final bool returned;

  /// The tutorial's computer player (PRD §4.9).
  final bool bot;

  factory PlayerView.fromJson(Map<String, dynamic> json) => PlayerView(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    seat: json['seat'] as int,
    total: json['total'] as int,
    connected: json['connected'] as bool,
    status: PlayerStatus.values.byName(json['status'] as String),
    row: _cards(json['row']),
    modifiers: _cards(json['modifiers']),
    secondChance: _card(json['secondChance']),
    played: _cards(json['played']),
    bustCard: _card(json['bustCard']),
    seventhCard: json['seventhCard'] as bool? ?? false,
    forced: json['forced'] as bool? ?? false,
    roundScore: json['roundScore'] as int? ?? 0,
    returned: json['returned'] as bool? ?? true,
    bot: json['bot'] as bool? ?? false,
  );
}

enum DecisionKind { hitOrStay, chooseTarget, giveSecondChance }

class Decision {
  const Decision({
    required this.id,
    required this.kind,
    required this.playerId,
    required this.deadline,
    this.canStay = false,
    this.card,
    this.targets = const [],
  });

  final String id;
  final DecisionKind kind;
  final String playerId;

  /// Server time (ms since epoch) when the decision times out.
  final int deadline;
  final bool canStay;
  final GameCard? card;
  final List<String> targets;

  factory Decision.fromJson(Map<String, dynamic> json) => Decision(
    id: json['id'] as String,
    kind: switch (json['kind']) {
      'hit_or_stay' => DecisionKind.hitOrStay,
      'choose_target' => DecisionKind.chooseTarget,
      _ => DecisionKind.giveSecondChance,
    },
    playerId: json['playerId'] as String,
    deadline: json['deadline'] as int,
    canStay: json['canStay'] as bool? ?? false,
    card: _card(json['card']),
    targets: (json['targets'] as List<dynamic>? ?? const []).cast<String>(),
  );
}

enum Phase { lobby, dealing, turns, roundOver, results, paused, abandoned }

enum GameMode { normal, hard }

class Pile {
  const Pile({required this.total, required this.counts, this.top});

  final int total;

  /// Cards left per type: `n0`–`n12`, `p2`–`p10`, `x2`, `freeze`, `flip_three`, `second_chance`.
  final Map<String, int> counts;

  /// The discard pile's top card. Never set for the deck.
  final GameCard? top;

  factory Pile.fromJson(Map<String, dynamic> json) => Pile(
    total: json['total'] as int,
    counts: (json['counts'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
    top: _card(json['top']),
  );
}

class Tiebreak {
  const Tiebreak({required this.roundNo, required this.playerIds});

  final int roundNo;
  final List<String> playerIds;
}

class Outcome {
  const Outcome({required this.winnerIds, required this.draw, this.playerIds = const []});

  final List<String> winnerIds;
  final bool draw;

  /// Everyone who played the game. Players who joined the room after it ended aren't in it.
  final List<String> playerIds;
}

enum DrawSource { deal, hit, flipThree }

/// The card revealed most recently this round, shown in the middle of the table (PRD §6.2).
class LastDraw {
  const LastDraw({required this.card, required this.playerId, required this.source});

  final GameCard card;
  final String playerId;
  final DrawSource source;

  factory LastDraw.fromJson(Map<String, dynamic> json) => LastDraw(
    card: GameCard.fromJson(json['card'] as Map<String, dynamic>),
    playerId: json['playerId'] as String,
    source: switch (json['source']) {
      'hit' => DrawSource.hit,
      'flipThree' => DrawSource.flipThree,
      _ => DrawSource.deal,
    },
  );
}

class FlipThreeProgress {
  const FlipThreeProgress({required this.playerId, required this.remaining});

  final String playerId;
  final int remaining;
}

/// Everything every player can see (PRD §8.5). The same view goes to everyone.
class RoomView {
  const RoomView({
    required this.phase,
    required this.mode,
    required this.targetScore,
    required this.forcedLine,
    required this.players,
    required this.hostId,
    required this.round,
    required this.roundPlayerIds,
    required this.dealerId,
    required this.turnPlayerId,
    required this.tiebreak,
    required this.decision,
    required this.flipThrees,
    required this.deck,
    required this.discard,
    required this.decksInPlay,
    required this.nextRoundAt,
    required this.resultsAt,
    required this.pausedAt,
    required this.outcome,
    this.lastDraw,
    this.tutorial = false,
  });

  final Phase phase;
  final GameMode mode;
  final int targetScore;
  final int forcedLine;

  /// In seat order.
  final List<PlayerView> players;
  final String? hostId;
  final int round;
  final List<String> roundPlayerIds;
  final String? dealerId;
  final String? turnPlayerId;
  final Tiebreak? tiebreak;
  final Decision? decision;
  final List<FlipThreeProgress> flipThrees;
  final Pile deck;
  final Pile discard;
  final int decksInPlay;
  final int? nextRoundAt;
  final int? resultsAt;
  final int? pausedAt;
  final Outcome? outcome;
  final LastDraw? lastDraw;

  /// A tutorial room: this player against the bot, to 50 points (PRD §4.9).
  final bool tutorial;

  PlayerView? player(String? id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool get isPlaying =>
      phase == Phase.dealing || phase == Phase.turns || phase == Phase.roundOver || phase == Phase.paused;

  factory RoomView.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>;
    final tiebreak = json['tiebreak'] as Map<String, dynamic>?;
    final outcome = json['outcome'] as Map<String, dynamic>?;
    final decision = json['decision'] as Map<String, dynamic>?;
    final lastDraw = json['lastDraw'] as Map<String, dynamic>?;
    return RoomView(
      phase: switch (json['phase']) {
        'lobby' => Phase.lobby,
        'dealing' => Phase.dealing,
        'turns' => Phase.turns,
        'round_over' => Phase.roundOver,
        'results' => Phase.results,
        'paused' => Phase.paused,
        _ => Phase.abandoned,
      },
      mode: settings['mode'] == 'hard' ? GameMode.hard : GameMode.normal,
      targetScore: settings['targetScore'] as int,
      forcedLine: json['forcedLine'] as int,
      players: (json['players'] as List<dynamic>).map((p) => PlayerView.fromJson(p as Map<String, dynamic>)).toList(),
      hostId: json['hostId'] as String?,
      round: json['round'] as int,
      roundPlayerIds: (json['roundPlayerIds'] as List<dynamic>).cast<String>(),
      dealerId: json['dealerId'] as String?,
      turnPlayerId: json['turnPlayerId'] as String?,
      tiebreak: tiebreak == null
          ? null
          : Tiebreak(
              roundNo: tiebreak['roundNo'] as int,
              playerIds: (tiebreak['playerIds'] as List<dynamic>).cast<String>(),
            ),
      decision: decision == null ? null : Decision.fromJson(decision),
      flipThrees: (json['flipThrees'] as List<dynamic>? ?? const [])
          .map((f) => FlipThreeProgress(playerId: f['playerId'] as String, remaining: f['remaining'] as int))
          .toList(),
      deck: Pile.fromJson(json['deck'] as Map<String, dynamic>),
      discard: Pile.fromJson(json['discard'] as Map<String, dynamic>),
      decksInPlay: json['decksInPlay'] as int? ?? 1,
      nextRoundAt: json['nextRoundAt'] as int?,
      resultsAt: json['resultsAt'] as int?,
      pausedAt: json['pausedAt'] as int?,
      outcome: outcome == null
          ? null
          : Outcome(
              winnerIds: (outcome['winnerIds'] as List<dynamic>).cast<String>(),
              draw: outcome['draw'] as bool,
              playerIds: (outcome['playerIds'] as List<dynamic>? ?? const []).cast<String>(),
            ),
      lastDraw: lastDraw == null ? null : LastDraw.fromJson(lastDraw),
      tutorial: json['tutorial'] as bool? ?? false,
    );
  }
}

/// A game event, kept as raw JSON for now. M5 turns these into animations (PRD §9.3).
class GameEvent {
  const GameEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

sealed class ServerMessage {
  const ServerMessage();

  /// Parses one message. Returns null for anything that isn't a known JSON message (for example `pong`).
  static ServerMessage? parse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    switch (decoded['type']) {
      case 'welcome':
        return WelcomeMessage(
          playerId: decoded['playerId'] as String,
          token: decoded['token'] as String,
          roomCode: decoded['roomCode'] as String,
        );
      case 'update':
        return UpdateMessage(
          version: decoded['version'] as int,
          serverNow: decoded['now'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          events: (decoded['events'] as List<dynamic>)
              .map((e) => GameEvent((e as Map<String, dynamic>)['type'] as String, e))
              .toList(),
          view: RoomView.fromJson(decoded['view'] as Map<String, dynamic>),
        );
      case 'error':
        return ErrorMessage(decoded['code'] as String);
      default:
        return null;
    }
  }
}

class WelcomeMessage extends ServerMessage {
  const WelcomeMessage({required this.playerId, required this.token, required this.roomCode});

  final String playerId;
  final String token;
  final String roomCode;
}

class UpdateMessage extends ServerMessage {
  const UpdateMessage({required this.version, required this.serverNow, required this.events, required this.view});

  final int version;
  final int serverNow;
  final List<GameEvent> events;
  final RoomView view;
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.code);

  final String code;
}

/// Close codes the server uses when it ends a connection on purpose (PRD §8.5.1). After any of
/// these the app must not reconnect.
abstract final class CloseCodes {
  static const quit = 1000;
  static const refused = 4000;
  static const replaced = 4001;
  static const roomClosed = 4002;
  static const rateLimited = 4003;

  static bool isFinal(int? code) => code == quit || (code != null && code >= 4000 && code <= 4003);
}

List<GameCard> _cards(Object? list) =>
    (list as List<dynamic>? ?? const []).map((c) => GameCard.fromJson(c as Map<String, dynamic>)).toList();

GameCard? _card(Object? json) => json == null ? null : GameCard.fromJson(json as Map<String, dynamic>);
