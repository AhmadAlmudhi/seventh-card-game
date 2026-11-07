import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seventh_card_game/app.dart';
import 'package:seventh_card_game/dev/fixtures.dart';
import 'package:seventh_card_game/dev/replay.dart';
import 'package:seventh_card_game/net/protocol.dart';
import 'package:seventh_card_game/screens/room_screen.dart';
import 'package:seventh_card_game/state/room_controller.dart';
import 'package:seventh_card_game/state/table_director.dart';
import 'package:seventh_card_game/widgets/last_card_stage.dart';
import 'package:seventh_card_game/widgets/table_motion.dart';

import 'helpers.dart';

GameEvent _event(String type, Map<String, dynamic> data) => GameEvent(type, {'type': type, ...data});

Map<String, dynamic> _number(String id, int value) => {'id': id, 'kind': 'number', 'value': value};

/// Whether the card is hidden by its animation (fully transparent).
bool _hidden(WidgetTester tester, String cardId) {
  final element = find.byWidgetPredicate((w) => w is MotionCard && w.cardId == cardId).evaluate().single;
  var hidden = false;
  void visit(Element e) {
    final w = e.widget;
    if (w is Opacity && w.opacity < 0.05) hidden = true;
    if (w is FadeTransition && w.opacity.value < 0.05) hidden = true;
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return hidden;
}

void main() {
  /// The game screen fed by hand: [show] sets what the server sent, then the test plays events.
  Future<(TableDirector, void Function(RoomView))> table(WidgetTester tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'x'});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...rig.overrides, roomProvider.overrideWith(ReplayRoomController.new)],
        child: SeventhCardApp(
          router: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const RoomScreen(code: 'K7Q2M'),
              ),
            ],
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(RoomScreen)));
    void show(RoomView view) => (container.read(roomProvider.notifier) as ReplayRoomController).show(
      RoomState(code: 'K7Q2M', status: LinkStatus.connected, playerId: fixtureMe, view: view, version: 1),
    );
    return (container.read(tableDirectorProvider.notifier), show);
  }

  Future<void> playOut(WidgetTester tester, TableDirector director) async {
    for (var i = 0; i < 40 && !director.idle; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('a card that comes straight back after the table clears is visible, not left faded out', (tester) async {
    final (director, show) = await table(tester);
    final base = fixtureState('game').view!;
    // Round 4 is over, and this player holds card X first in their row.
    final x = GameCard.fromJson(_number('X', 10));
    final over = base
        .copyWith(phase: Phase.roundOver, decision: null)
        .withPlayer(fixtureMe, (p) => p.copyWith(row: [x, ...p.row.skip(1)]));
    show(over);
    director.receive(over, const [], snap: true, myId: fixtureMe);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_hidden(tester, 'X'), isFalse);

    // Round 5: the discard pile was reshuffled into the deck and X comes straight back to them, so
    // the card fading out with the old round is the very card dealt into the same place.
    final next = base
        .copyWith(phase: Phase.dealing, round: 5, decision: null)
        .withPlayer(fixtureMe, (p) => p.copyWith(row: [x], modifiers: const [], secondChance: null));
    show(next);
    director.receive(next, [
      _event('roundStarted', {
        'round': 5,
        'dealerId': 'noura',
        'playerIds': [for (final p in base.players) p.id],
      }),
      _event('cardDealt', {'to': fixtureMe, 'card': _number('X', 10), 'source': 'deal'}),
    ], myId: fixtureMe);
    await playOut(tester, director);
    expect(director.idle, isTrue);
    expect(_hidden(tester, 'X'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the card in the middle keeps its animation state when the phase changes', (tester) async {
    final (director, show) = await table(tester);
    final dealing = fixtureState('game').view!.copyWith(phase: Phase.dealing, decision: null);
    show(dealing);
    director.receive(dealing, const [], snap: true, myId: fixtureMe);
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.state(find.byType(LastCardStage));

    // The deal ends and turns begin, then the next card is revealed.
    final card = GameCard.fromJson(_number('Y', 7));
    final turns = dealing
        .copyWith(
          phase: Phase.turns,
          turnPlayerId: 'sara',
          lastDraw: LastDraw(card: card, playerId: 'sara', source: DrawSource.hit),
        )
        .withPlayer('sara', (p) => p.copyWith(row: [...p.row, card]));
    show(turns);
    director.receive(turns, [
      _event('turnStarted', {'playerId': 'sara', 'forced': false}),
      _event('cardDealt', {'to': 'sara', 'card': _number('Y', 7), 'source': 'hit'}),
    ], myId: fixtureMe);
    await playOut(tester, director);
    expect(identical(tester.state(find.byType(LastCardStage)), before), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
