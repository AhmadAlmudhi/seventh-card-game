import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/dev/fixtures.dart';
import 'package:seventh_card_game/net/protocol.dart';
import 'package:seventh_card_game/state/room_controller.dart';
import 'package:seventh_card_game/state/stage_effect.dart';
import 'package:seventh_card_game/state/table_director.dart';
import 'package:seventh_card_game/theme/motion.dart';

import 'helpers.dart';

RoomView _viewOf(Map<String, dynamic> json) => RoomView.fromJson(json['view'] as Map<String, dynamic>);

List<GameEvent> _eventsOf(Map<String, dynamic> json) => [
  for (final e in (json['events'] as List<dynamic>).cast<Map<String, dynamic>>()) GameEvent(e['type'] as String, e),
];

GameEvent _event(String type, Map<String, dynamic> data) => GameEvent(type, {'type': type, ...data});

Map<String, dynamic> _number(String id, int value) => {'id': id, 'kind': 'number', 'value': value};

/// The room as it was in the lobby, just before [started].
RoomView _lobbyBefore(RoomView started) => started.copyWith(
  phase: Phase.lobby,
  round: 0,
  decision: null,
  turnPlayerId: null,
  lastDraw: null,
  players: [for (final p in started.players) p.copyWith(row: const [], modifiers: const [])],
);

void main() {
  late ProviderContainer container;
  TableDirector director() => container.read(tableDirectorProvider.notifier);
  TableState table() => container.read(tableDirectorProvider);

  /// A test on Flutter's fake clock, so beats advance with `tester.pump`. [room] is what the
  /// server last sent, for this player's decision.
  void directorTest(String description, Future<void> Function(WidgetTester tester) body, {RoomState? room}) {
    testWidgets(description, (tester) async {
      container = ProviderContainer(
        overrides: [if (room != null) roomProvider.overrideWith(() => FixtureRoomController(room))],
      );
      try {
        await body(tester);
      } finally {
        container.dispose();
      }
    });
  }

  final started = fixtureJson('update_started');
  final target = _viewOf(started);
  final ali = target.players[0];
  final sara = target.players[1];

  directorTest('plays a deal one card at a time, then shows exactly the server’s view (PRD §9.3)', (tester) async {
    director().receive(_lobbyBefore(target), const [], snap: true);
    expect(table().shown!.phase, Phase.lobby);

    director().receive(target, _eventsOf(started));
    // The round starts: the table clears for a moment.
    expect(table().cue!.type, 'roundStarted');
    expect(table().shown!.phase, Phase.dealing);

    await tester.pump(AppMotion.beatClear);
    // Ali's card is revealed in the middle and flies to his row.
    expect(table().cue!.type, 'cardDealt');
    expect(table().shown!.player(ali.id)!.row.map((c) => c.value), [6]);
    expect(table().shown!.player(sara.id)!.row, isEmpty);
    expect(table().arriving, {ali.row.single.id});
    expect(table().stage!.draw.card, ali.row.single);
    final firstPlay = table().stage!.play;

    await tester.pump(AppMotion.beatDeal);
    expect(table().shown!.player(sara.id)!.row.map((c) => c.value), [8]);
    expect(table().stage!.play, firstPlay + 1);
    expect(table().shown!.decision, isNull, reason: 'the decision waits for the deal to finish');

    await tester.pump(AppMotion.beatDeal);
    expect(identical(table().shown, target), isTrue);
    expect(table().cue, isNull);
  });

  directorTest('this player’s Hit/Stay only opens once the beats before it have played', (tester) async {
    director().receive(_lobbyBefore(target), const [], snap: true);
    director().receive(target, _eventsOf(started));
    expect(container.read(myDecisionProvider), isNull);
    await tester.pump(AppMotion.beatClear + AppMotion.beatDeal * 2);
    expect(container.read(myDecisionProvider)?.id, target.decision!.id);
  }, room: RoomState(code: 'ABCDE', playerId: ali.id, view: target));

  directorTest('a duplicate never joins the row: it busts, and the stage plays the bust', (tester) async {
    final turn = target.copyWith(phase: Phase.turns);
    director().receive(turn, const [], snap: true);
    final duplicate = _number('dup', 6);
    final events = [
      _event('cardDealt', {'to': ali.id, 'card': duplicate, 'source': 'hit'}),
      _event('busted', {'playerId': ali.id, 'duplicate': duplicate}),
    ];
    final after = turn.withPlayer(
      ali.id,
      (p) => p.copyWith(status: PlayerStatus.busted, bustCard: GameCard.fromJson(duplicate)),
    );
    director().receive(after, events);
    expect(table().shown!.player(ali.id)!.row.map((c) => c.id), ali.row.map((c) => c.id));
    expect(table().stage!.effect, StageEffect.bust);
    expect(table().arriving, isEmpty);

    await tester.pump(AppMotion.beatDuplicate);
    expect(table().cue!.type, 'busted');
    expect(table().shown!.player(ali.id)!.status, PlayerStatus.busted);
    expect(table().arriving, {'dup'}, reason: 'the duplicate flies to the end of the row');
    await tester.pump(AppMotion.bust);
  });

  directorTest('a used Second Chance plays its exit, then leaves the row', (tester) async {
    const sc = {'id': 'sc', 'kind': 'action', 'action': 'second_chance'};
    final holding = target
        .copyWith(phase: Phase.turns)
        .withPlayer(ali.id, (p) => p.copyWith(secondChance: GameCard.fromJson(sc)));
    director().receive(holding, const [], snap: true);
    final duplicate = _number('dup', 6);
    director().receive(target.copyWith(phase: Phase.turns), [
      _event('cardDealt', {'to': ali.id, 'card': duplicate, 'source': 'hit'}),
      _event('secondChanceUsed', {'playerId': ali.id, 'card': sc, 'duplicate': duplicate}),
    ]);
    expect(table().stage!.effect, StageEffect.saved);
    await tester.pump(AppMotion.beatDuplicate);
    expect(table().leaving, {'sc'});
    expect(table().shown!.player(ali.id)!.secondChance?.id, 'sc', reason: 'still there while it leaves');
    await tester.pump(AppMotion.secondChance);
    expect(table().shown!.player(ali.id)!.secondChance, isNull);
  });

  directorTest('falls more than 5 s behind and it skips to the last update, then plays the new one', (tester) async {
    director().receive(_lobbyBefore(target), const [], snap: true);
    final deal = [
      for (var i = 0; i < 12; i++) _event('cardDealt', {'to': ali.id, 'card': _number('c$i', i), 'source': 'deal'}),
    ];
    director().receive(target, deal);
    expect(table().skips, 0);
    director().receive(target, deal);
    expect(table().skips, 1);
    expect(table().cue!.type, 'cardDealt', reason: 'the newest update still plays');
    await tester.pump(const Duration(seconds: 10));
  });

  directorTest('coming back to the app catches the table up at once', (tester) async {
    director().receive(_lobbyBefore(target), const [], snap: true);
    director().receive(target, _eventsOf(started));
    director().skipToEnd();
    expect(identical(table().shown, target), isTrue);
    expect(table().skips, 1);
  });

  test('beats: a forced draw shows its badge, the last round lingers before the results', () {
    expect(
      beatMs([
        _event('turnStarted', {'playerId': 'p', 'forced': true}),
      ], 0),
      AppMotion.beatShort.inMilliseconds,
    );
    expect(
      beatMs([
        _event('turnStarted', {'playerId': 'p', 'forced': false}),
      ], 0),
      0,
    );
    final scored = _event('roundScored', {'scores': <Object>[]});
    expect(beatMs([scored], 0), 0);
    expect(beatMs([scored, _event('gameOver', {})], 0), AppMotion.beatFinalRound.inMilliseconds);
    expect(beatMs([_event('playerJoined', {})], 0), isNull, reason: 'lobby events have nothing to play');
    final tiebreak = _event('roundStarted', {
      'round': 9,
      'dealerId': 'p',
      'playerIds': ['p', 'q'],
      'tiebreak': {
        'roundNo': 1,
        'playerIds': ['p', 'q'],
      },
    });
    expect(beatMs([tiebreak], 0), AppMotion.beatTiebreak.inMilliseconds, reason: 'its introduction plays first');
  });
}
