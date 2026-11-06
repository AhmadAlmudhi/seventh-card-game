import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/net/protocol.dart';

import 'helpers.dart';

void main() {
  group('server messages (recorded from a real server)', () {
    test('parses a welcome', () {
      final message = ServerMessage.parse(fixtureJson('welcome'));
      expect(message, isA<WelcomeMessage>());
      final welcome = message! as WelcomeMessage;
      expect(welcome.token, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(welcome.roomCode, matches(RegExp(r'^[A-Z2-9]{5}$')));
    });

    test('parses an update with the whole public view', () {
      final message = ServerMessage.parse(fixtureJson('update_started'));
      expect(message, isA<UpdateMessage>());
      final update = message! as UpdateMessage;
      final view = update.view;
      expect(update.events.first.type, 'gameStarted');
      expect(update.serverNow, greaterThan(0));
      expect(view.phase, Phase.turns);
      expect(view.players, hasLength(2));
      expect(view.players.map((p) => p.nickname), ['Ali', 'سارة']);
      expect(view.decision?.kind, DecisionKind.hitOrStay);
      expect(
        view.deck.total +
            view.players.fold<int>(
              0,
              (n, p) => n + p.row.length + p.modifiers.length + p.played.length + (p.secondChance == null ? 0 : 1),
            ),
        lessThanOrEqualTo(94),
      );
      expect(view.deck.counts.keys, containsAll(['n0', 'n12', 'p10', 'x2', 'freeze', 'flip_three', 'second_chance']));
      expect(view.round, 1);
    });

    test('parses a tutorial update: the bot, the 50-point target and the last card (PRD §4.9, §6.2)', () {
      final update = ServerMessage.parse(fixtureJson('update_tutorial'))! as UpdateMessage;
      final view = update.view;
      expect(view.tutorial, isTrue);
      expect(view.targetScore, 50);
      expect(view.players.where((p) => p.bot).map((p) => p.id), ['bot']);
      expect(view.players.where((p) => !p.bot), hasLength(1));
      final last = view.lastDraw!;
      expect(last.source, DrawSource.deal);
      expect(view.player(last.playerId)!.row, contains(last.card));
    });

    test('a normal room is no tutorial and has no bot', () {
      final view = (ServerMessage.parse(fixtureJson('update_started'))! as UpdateMessage).view;
      expect(view.tutorial, isFalse);
      expect(view.players.any((p) => p.bot), isFalse);
    });

    test('ignores the pong keepalive and unknown messages', () {
      expect(ServerMessage.parse('pong'), isNull);
      expect(ServerMessage.parse({'type': 'something-new'}), isNull);
    });

    test('parses every card kind', () {
      expect(GameCard.fromJson({'id': 'd1-0', 'kind': 'number', 'value': 0}).kind, CardKind.number);
      expect(GameCard.fromJson({'id': 'd1-79', 'kind': 'plus', 'amount': 4}).value, 4);
      expect(GameCard.fromJson({'id': 'd1-84', 'kind': 'x2'}).kind, CardKind.x2);
      expect(GameCard.fromJson({'id': 'd1-85', 'kind': 'action', 'action': 'freeze'}).kind, CardKind.freeze);
      expect(GameCard.fromJson({'id': 'd1-88', 'kind': 'action', 'action': 'flip_three'}).kind, CardKind.flipThree);
      expect(
        GameCard.fromJson({'id': 'd1-91', 'kind': 'action', 'action': 'second_chance'}).kind,
        CardKind.secondChance,
      );
    });

    test('knows which close codes are final', () {
      for (final code in [1000, 4000, 4001, 4002, 4003]) {
        expect(CloseCodes.isFinal(code), isTrue, reason: '$code');
      }
      for (final code in [null, 1001, 1006, 1011]) {
        expect(CloseCodes.isFinal(code), isFalse, reason: '$code');
      }
    });
  });
}
