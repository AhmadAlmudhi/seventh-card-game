// Sample room states for the screen gallery and widget tests. Not used by the app itself.
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../state/tutorial_coach.dart';

const fixtureCode = 'K7Q2M';
const fixtureMe = 'me';

GameCard _n(int value, [String suffix = '']) => GameCard(id: 'n$value$suffix', kind: CardKind.number, value: value);
GameCard _plus(int value) => GameCard(id: 'p$value', kind: CardKind.plus, value: value);
const _x2 = GameCard(id: 'x2', kind: CardKind.x2);
const _sc = GameCard(id: 'sc', kind: CardKind.secondChance);
const _freeze = GameCard(id: 'fz', kind: CardKind.freeze);
const _drawThree = GameCard(id: 'd3', kind: CardKind.drawThree);

PlayerView _player(
  String id,
  String nickname,
  int seat, {
  int total = 0,
  PlayerStatus status = PlayerStatus.active,
  List<GameCard> row = const [],
  List<GameCard> modifiers = const [],
  GameCard? secondChance,
  GameCard? bustCard,
  bool connected = true,
  bool forced = false,
  int roundScore = 0,
  bool returned = true,
  bool bot = false,
  bool seventhCard = false,
}) => PlayerView(
  id: id,
  nickname: nickname,
  seat: seat,
  total: total,
  connected: connected,
  status: status,
  row: row,
  modifiers: modifiers,
  secondChance: secondChance,
  played: const [],
  bustCard: bustCard,
  seventhCard: seventhCard,
  forced: forced,
  roundScore: roundScore,
  returned: returned,
  bot: bot,
);

Map<String, int> _counts(int total) {
  final counts = <String, int>{for (var v = 0; v <= 12; v++) 'n$v': v == 0 ? 1 : (v * 0.7).round()};
  for (final key in ['p2', 'p4', 'p6', 'p8', 'p10', 'x2']) {
    counts[key] = 1;
  }
  counts['x2'] = 0;
  for (final key in ['freeze', 'draw_three', 'second_chance']) {
    counts[key] = 2;
  }
  counts['n0'] = total > 60 ? 1 : 0;
  return counts;
}

RoomView _view({
  required Phase phase,
  required List<PlayerView> players,
  String? hostId = fixtureMe,
  Decision? decision,
  int round = 4,
  GameMode mode = GameMode.normal,
  int target = 200,
  Outcome? outcome,
  Tiebreak? tiebreak,
  int? scoredTiebreakRound,
  int? nextRoundAt,
  String? turnPlayerId,
  LastDraw? lastDraw,
  bool tutorial = false,
  String dealerId = 'omar',
  List<DrawThreeProgress> drawThrees = const [],
}) => RoomView(
  phase: phase,
  mode: mode,
  targetScore: target,
  forcedLine: (target * 0.75).floor(),
  players: players,
  hostId: hostId,
  round: round,
  roundPlayerIds: [for (final p in players) p.id],
  dealerId: dealerId,
  turnPlayerId: turnPlayerId ?? decision?.playerId,
  tiebreak: tiebreak,
  decision: decision,
  drawThrees: drawThrees,
  deck: Pile(total: 52, counts: _counts(52)),
  discard: Pile(total: 29, counts: _counts(29), top: _n(9, 'd')),
  decksInPlay: 1,
  nextRoundAt: nextRoundAt,
  resultsAt: null,
  pausedAt: null,
  outcome: outcome,
  lastDraw: lastDraw,
  tutorial: tutorial,
  scoredTiebreakRound: scoredTiebreakRound,
);

LastDraw _drew(GameCard card, String playerId, [DrawSource source = DrawSource.hit]) =>
    LastDraw(card: card, playerId: playerId, source: source);

int get _soon => DateTime.now().millisecondsSinceEpoch + 9000;

RoomState fixtureState(String name) {
  final now = DateTime.now().millisecondsSinceEpoch;
  RoomState state(RoomView view) =>
      RoomState(code: fixtureCode, status: LinkStatus.connected, playerId: fixtureMe, view: view);

  final lobbyPlayers = [
    _player(fixtureMe, 'عبدالله', 0),
    _player('sara', 'سارة', 1),
    _player('omar', 'Omar', 2, connected: false),
    _player('noura', 'نورة', 3),
  ];

  final tablePlayers = [
    _player(
      fixtureMe,
      'عبدالله',
      0,
      total: 140,
      row: [_n(3), _n(7), _n(11), _n(0), _n(5)],
      modifiers: [_plus(6), _x2],
      secondChance: _sc,
      roundScore: 58,
    ),
    _player('sara', 'سارة', 1, total: 112, row: [_n(4), _n(9)], modifiers: [_plus(2)], roundScore: 15),
    _player('omar', 'Omar', 2, total: 87, status: PlayerStatus.stayed, row: [_n(6), _n(1), _n(12)], roundScore: 19),
    _player('noura', 'نورة', 3, total: 45, status: PlayerStatus.busted, row: [_n(8), _n(3, 'b')], bustCard: _n(8, 'x')),
  ];

  // A full table: 8 players, every status, long rows (PRD §6.0's worst case).
  final fullTable = [
    _player(
      fixtureMe,
      'عبدالله',
      0,
      total: 140,
      row: [_n(3), _n(7), _n(11), _n(0), _n(5), _n(9)],
      modifiers: [_plus(6), _x2],
      secondChance: _sc,
      roundScore: 76,
    ),
    _player('sara', 'سارة', 1, total: 112, row: [_n(4), _n(9, 's'), _n(12)], modifiers: [_plus(2)], roundScore: 27),
    _player(
      'omar',
      'Omar',
      2,
      total: 87,
      status: PlayerStatus.stayed,
      row: [_n(6), _n(1), _n(12, 'o')],
      roundScore: 19,
    ),
    _player('noura', 'نورة', 3, total: 45, status: PlayerStatus.busted, row: [_n(8), _n(3, 'b')], bustCard: _n(8, 'x')),
    _player(
      'fahad',
      'فهد',
      4,
      total: 163,
      row: [_n(2), _n(10), _n(5, 'f'), _n(7, 'f'), _n(11, 'f'), _n(4, 'f')],
      roundScore: 39,
      forced: true,
    ),
    _player('reem', 'ريم', 5, total: 98, status: PlayerStatus.frozen, row: [_n(10, 'r'), _n(6, 'r')], roundScore: 16),
    _player('khalid', 'Khalid', 6, total: 120, row: [_n(9, 'k')], roundScore: 9, connected: false),
    _player(
      'huda',
      'هدى',
      7,
      total: 74,
      status: PlayerStatus.stayed,
      row: [_n(12, 'h'), _n(11, 'h'), _n(8, 'h')],
      modifiers: [_plus(10)],
      roundScore: 41,
    ),
  ];
  const bot = 'bot';
  final tutorialPlayers = [
    _player(fixtureMe, 'عبدالله', 0, total: 23, row: [_n(6), _n(2)], roundScore: 8),
    _player(bot, 'Robo', 1, total: 31, row: [_n(9), _n(4), _n(12)], modifiers: [_plus(4)], roundScore: 29, bot: true),
  ];

  switch (name) {
    case 'game-8':
      return state(
        _view(
          phase: Phase.turns,
          players: fullTable,
          dealerId: 'reem',
          lastDraw: _drew(_n(8, 'x'), 'noura'),
          decision: Decision(id: 'q8', kind: DecisionKind.hitOrStay, playerId: 'fahad', deadline: _soon, canStay: true),
        ),
      );
    case 'game-8-mine':
      return state(
        _view(
          phase: Phase.turns,
          players: fullTable,
          dealerId: 'reem',
          lastDraw: _drew(_n(9), fixtureMe),
          decision: Decision(
            id: 'q9',
            kind: DecisionKind.hitOrStay,
            playerId: fixtureMe,
            deadline: _soon,
            canStay: true,
          ),
        ),
      );
    case 'lobby-8':
      return state(
        _view(
          phase: Phase.lobby,
          round: 0,
          players: [for (final p in fullTable) _player(p.id, p.nickname, p.seat, connected: p.id != 'khalid')],
        ),
      );
    case 'tutorial':
      return state(
        _view(
          phase: Phase.turns,
          round: 3,
          target: 50,
          tutorial: true,
          dealerId: bot,
          players: tutorialPlayers,
          lastDraw: _drew(_n(2), fixtureMe),
          decision: Decision(
            id: 'q10',
            kind: DecisionKind.hitOrStay,
            playerId: fixtureMe,
            deadline: now + 300000,
            canStay: true,
          ),
        ),
      );
    case 'tutorial-bot':
      return state(
        _view(
          phase: Phase.turns,
          round: 3,
          target: 50,
          tutorial: true,
          dealerId: bot,
          players: [
            tutorialPlayers[0],
            _player(bot, 'Robo', 1, total: 31, row: [_n(9), _n(4)], roundScore: 13, bot: true),
          ],
          lastDraw: _drew(_drawThree, bot),
          decision: Decision(
            id: 'q11',
            kind: DecisionKind.chooseTarget,
            playerId: bot,
            deadline: now + 1500,
            card: _drawThree,
            targets: const [fixtureMe, bot],
          ),
        ),
      );
    case 'tutorial-results':
      return state(
        _view(
          phase: Phase.results,
          round: 6,
          target: 50,
          tutorial: true,
          outcome: const Outcome(winnerIds: [fixtureMe], draw: false),
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 58, returned: false),
            _player(bot, 'Robo', 1, total: 44, bot: true),
          ],
        ),
      );
    case 'lobby-guest':
      return state(_view(phase: Phase.lobby, players: lobbyPlayers, hostId: 'sara', round: 0));
    case 'lobby-waiting':
      return state(
        _view(
          phase: Phase.results,
          round: 9,
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 212),
            _player('sara', 'سارة', 1, total: 188, returned: false),
            _player('omar', 'Omar', 2, total: 140, returned: false),
          ],
        ),
      );
    case 'game':
    case 'counter':
      return state(
        _view(
          phase: Phase.turns,
          players: tablePlayers,
          lastDraw: _drew(_n(5), fixtureMe),
          decision: Decision(
            id: 'q1',
            kind: DecisionKind.hitOrStay,
            playerId: fixtureMe,
            deadline: _soon,
            canStay: true,
          ),
        ),
      );
    case 'game-waiting':
      return state(
        _view(
          phase: Phase.turns,
          players: tablePlayers,
          lastDraw: _drew(_plus(2), 'sara'),
          decision: Decision(id: 'q2', kind: DecisionKind.hitOrStay, playerId: 'sara', deadline: _soon, canStay: true),
        ),
      );
    case 'game-choose':
      return state(
        _view(
          phase: Phase.turns,
          players: tablePlayers,
          lastDraw: _drew(_freeze, fixtureMe),
          decision: Decision(
            id: 'q3',
            kind: DecisionKind.chooseTarget,
            playerId: fixtureMe,
            deadline: _soon,
            card: _freeze,
            targets: const [fixtureMe, 'sara'],
          ),
        ),
      );
    case 'round-over':
      return state(
        _view(
          phase: Phase.roundOver,
          players: [
            for (final p in tablePlayers)
              _player(
                p.id,
                p.nickname,
                p.seat,
                total: p.total + p.roundScore,
                status: p.status,
                row: p.row,
                modifiers: p.modifiers,
                bustCard: p.bustCard,
                roundScore: p.roundScore,
              ),
          ],
          nextRoundAt: now + 3500,
        ),
      );
    case 'hard':
      // Hard Mode (Rules §11): past the forced-Hit line, and someone's bust costs 5.
      return state(
        _view(
          phase: Phase.turns,
          mode: GameMode.hard,
          target: 400,
          turnPlayerId: fixtureMe,
          lastDraw: _drew(_n(8), fixtureMe),
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 320, row: [_n(4), _n(8)], roundScore: 12, forced: true),
            _player('sara', 'سارة', 1, total: 280, row: [_n(9), _n(12)], roundScore: 21),
            _player('omar', 'Omar', 2, total: 190, row: [_n(6), _n(1), _n(12, 'o')], roundScore: 19),
            _player(
              'noura',
              'نورة',
              3,
              total: 304,
              status: PlayerStatus.busted,
              row: [_n(7), _n(3)],
              bustCard: _n(7, 'x'),
              roundScore: -5,
              forced: true,
            ),
          ],
        ),
      );
    case 'tiebreak-over':
      // The break after tie-break round 1: totals didn't change, and a second round is coming.
      return state(
        _view(
          phase: Phase.roundOver,
          round: 12,
          scoredTiebreakRound: 1,
          tiebreak: const Tiebreak(roundNo: 2, playerIds: [fixtureMe, 'sara']),
          nextRoundAt: now + 3500,
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 210, row: [_n(6), _n(9)], roundScore: 15),
            _player('sara', 'سارة', 1, total: 210, row: [_n(5), _n(10)], roundScore: 15),
            _player('omar', 'Omar', 2, total: 160, status: PlayerStatus.watching),
          ],
        ),
      );
    case 'results-tiebreak':
      return state(
        _view(
          phase: Phase.results,
          round: 13,
          outcome: const Outcome(winnerIds: [fixtureMe], draw: false, tiebreakRounds: 2),
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 210, returned: false),
            _player('sara', 'سارة', 1, total: 210, returned: false),
            _player('omar', 'Omar', 2, total: 160, returned: false),
          ],
        ),
      );
    case 'paused':
      return state(_view(phase: Phase.paused, players: tablePlayers));
    case 'results':
      return state(
        _view(
          phase: Phase.results,
          round: 9,
          outcome: const Outcome(winnerIds: ['sara'], draw: false, playerIds: [fixtureMe, 'sara', 'omar', 'noura']),
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 188, returned: false),
            _player('sara', 'سارة', 1, total: 212, returned: false),
            _player('omar', 'Omar', 2, total: 140),
            _player('noura', 'نورة', 3, total: 61, status: PlayerStatus.left),
            // Joined the room after the game, once Omar was back (Rules §12.9).
            _player('reem', 'ريم', 4),
          ],
        ),
      );
    case 'error':
      return const RoomState(code: fixtureCode, status: LinkStatus.closed, error: 'SEAT_LOST');
    case 'lobby':
    default:
      return state(_view(phase: Phase.lobby, players: lobbyPlayers, round: 0, mode: GameMode.hard, target: 400));
  }
}

/// The tip each tutorial fixture shows.
CoachState fixtureCoach(String name) => switch (name) {
  'tutorial' => const CoachState(seen: {CoachTip.welcome, CoachTip.turn, CoachTip.risk}, queue: [CoachTip.risk]),
  'tutorial-bot' => const CoachState(seen: {CoachTip.drawThree}, queue: [CoachTip.drawThree]),
  _ => const CoachState(),
};

/// A coach that just shows a fixed tip.
class FixtureCoach extends TutorialCoach {
  FixtureCoach(this.fixture);

  final CoachState fixture;

  @override
  CoachState build() => fixture;
}

/// A room controller that just shows a fixed state, with no network.
class FixtureRoomController extends RoomController {
  FixtureRoomController(this.fixture);

  final RoomState fixture;

  @override
  RoomState build() => fixture;

  @override
  Future<void> enter(String code, String nickname) async {}
}
