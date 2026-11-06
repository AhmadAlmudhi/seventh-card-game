// Sample room states for the screen gallery and widget tests. Not used by the app itself.
import '../net/protocol.dart';
import '../state/room_controller.dart';

const fixtureCode = 'K7Q2M';
const fixtureMe = 'me';

GameCard _n(int value, [String suffix = '']) => GameCard(id: 'n$value$suffix', kind: CardKind.number, value: value);
GameCard _plus(int value) => GameCard(id: 'p$value', kind: CardKind.plus, value: value);
const _x2 = GameCard(id: 'x2', kind: CardKind.x2);
const _sc = GameCard(id: 'sc', kind: CardKind.secondChance);
const _freeze = GameCard(id: 'fz', kind: CardKind.freeze);

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
  seventhCard: false,
  forced: forced,
  roundScore: roundScore,
  returned: returned,
);

Map<String, int> _counts(int total) {
  final counts = <String, int>{for (var v = 0; v <= 12; v++) 'n$v': v == 0 ? 1 : (v * 0.7).round()};
  for (final key in ['p2', 'p4', 'p6', 'p8', 'p10', 'x2']) {
    counts[key] = 1;
  }
  counts['x2'] = 0;
  for (final key in ['freeze', 'flip_three', 'second_chance']) {
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
  int? nextRoundAt,
  String? turnPlayerId,
}) => RoomView(
  phase: phase,
  mode: mode,
  targetScore: target,
  forcedLine: (target * 0.75).floor(),
  players: players,
  hostId: hostId,
  round: round,
  roundPlayerIds: [for (final p in players) p.id],
  dealerId: 'omar',
  turnPlayerId: turnPlayerId ?? decision?.playerId,
  tiebreak: null,
  decision: decision,
  flipThrees: const [],
  deck: Pile(total: 52, counts: _counts(52)),
  discard: Pile(total: 29, counts: _counts(29), top: _n(9, 'd')),
  decksInPlay: 1,
  nextRoundAt: nextRoundAt,
  resultsAt: null,
  pausedAt: null,
  outcome: outcome,
);

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

  switch (name) {
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
      return state(
        _view(
          phase: Phase.turns,
          players: tablePlayers,
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
          decision: Decision(id: 'q2', kind: DecisionKind.hitOrStay, playerId: 'sara', deadline: _soon, canStay: true),
        ),
      );
    case 'game-choose':
      return state(
        _view(
          phase: Phase.turns,
          players: tablePlayers,
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
    case 'paused':
      return state(_view(phase: Phase.paused, players: tablePlayers));
    case 'results':
      return state(
        _view(
          phase: Phase.results,
          round: 9,
          outcome: const Outcome(winnerIds: ['sara'], draw: false),
          players: [
            _player(fixtureMe, 'عبدالله', 0, total: 188, returned: false),
            _player('sara', 'سارة', 1, total: 212, returned: false),
            _player('omar', 'Omar', 2, total: 140, returned: false),
            _player('noura', 'نورة', 3, total: 61, status: PlayerStatus.left),
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

/// A room controller that just shows a fixed state, with no network.
class FixtureRoomController extends RoomController {
  FixtureRoomController(this.fixture);

  final RoomState fixture;

  @override
  RoomState build() => fixture;

  @override
  Future<void> enter(String code, String nickname) async {}
}
