import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/dev/fixtures.dart';
import 'package:seventh_card_game/net/protocol.dart';
import 'package:seventh_card_game/state/tutorial_coach.dart';
import 'package:seventh_card_game/widgets/last_card_stage.dart';

GameCard _n(int value, String id) => GameCard(id: id, kind: CardKind.number, value: value);

PlayerView _player({
  List<GameCard> row = const [],
  GameCard? bustCard,
  bool seventhCard = false,
  PlayerStatus status = PlayerStatus.active,
}) => PlayerView(
  id: 'p',
  nickname: 'Ali',
  seat: 0,
  total: 0,
  connected: true,
  status: status,
  row: row,
  modifiers: const [],
  secondChance: null,
  played: const [],
  bustCard: bustCard,
  seventhCard: seventhCard,
  forced: false,
  roundScore: 0,
  returned: true,
);

LastDraw _drew(GameCard card) => LastDraw(card: card, playerId: 'p', source: DrawSource.hit);

void main() {
  group('the last card’s effect (PRD §6.2) is read off the view', () {
    test('a number added to the row is plain', () {
      final card = _n(5, 'a');
      expect(stageEffectFor(_drew(card), _player(row: [card])), StageEffect.plain);
    });

    test('the duplicate that busted a player is a bust', () {
      final card = _n(5, 'b');
      expect(
        stageEffectFor(_drew(card), _player(row: [_n(5, 'a')], bustCard: card, status: PlayerStatus.busted)),
        StageEffect.bust,
      );
    });

    test('a duplicate that is neither in the row nor the bust card was saved by a Second Chance', () {
      expect(stageEffectFor(_drew(_n(5, 'b')), _player(row: [_n(5, 'a')])), StageEffect.saved);
    });

    test('the seventh different number is the Seventh Card', () {
      final row = [for (var v = 0; v < 7; v++) _n(v, 'r$v')];
      expect(stageEffectFor(_drew(row.last), _player(row: row, seventhCard: true)), StageEffect.seventh);
    });

    test('action and modifier cards have their own effects', () {
      expect(stageEffectFor(_drew(const GameCard(id: 'f', kind: CardKind.freeze)), _player()), StageEffect.freeze);
      expect(
        stageEffectFor(_drew(const GameCard(id: 't', kind: CardKind.flipThree)), _player()),
        StageEffect.flipThree,
      );
      expect(
        stageEffectFor(_drew(const GameCard(id: 's', kind: CardKind.secondChance)), _player()),
        StageEffect.secondChance,
      );
      expect(stageEffectFor(_drew(const GameCard(id: 'x', kind: CardKind.x2)), _player()), StageEffect.modifier);
      expect(
        stageEffectFor(_drew(const GameCard(id: 'p', kind: CardKind.plus, value: 4)), _player()),
        StageEffect.modifier,
      );
    });
  });

  group('the tutorial coach (PRD §4.9)', () {
    late ProviderContainer container;
    TutorialCoach coach() => container.read(tutorialCoachProvider.notifier);
    CoachState state() => container.read(tutorialCoachProvider);
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('welcomes, then explains the turn, each tip once', () {
      final view = fixtureState('tutorial').view!;
      coach().observe(view, const [], fixtureMe);
      expect(state().queue, [CoachTip.welcome, CoachTip.turn, CoachTip.risk]);
      coach().dismiss();
      expect(state().current, CoachTip.turn);
      coach().observe(view, const [], fixtureMe);
      expect(state().queue, [CoachTip.turn, CoachTip.risk], reason: 'nothing repeats');
    });

    test('explains a special card the first time anyone draws one', () {
      coach().observe(fixtureState('tutorial-bot').view!, const [], fixtureMe);
      expect(state().queue, [CoachTip.welcome, CoachTip.flipThree]);
    });

    test('starts over for a new tutorial', () {
      coach().observe(fixtureState('tutorial').view!, const [], fixtureMe);
      coach().reset();
      expect(state().queue, isEmpty);
      expect(state().seen, isEmpty);
    });

    test('stays quiet outside a tutorial', () {
      coach().observe(fixtureState('game').view!, const [], fixtureMe);
      expect(state().queue, isEmpty);
    });
  });
}
