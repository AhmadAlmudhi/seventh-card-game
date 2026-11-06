import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/protocol.dart';
import '../theme/motion.dart';
import 'room_controller.dart';
import 'stage_effect.dart';
import 'tutorial_coach.dart';

/// The event the table is showing right now, so widgets can play their one-off effect.
@immutable
class TableCue {
  const TableCue(this.event, this.seq);

  final GameEvent event;

  /// Unique per beat, so the same kind of event twice still plays twice.
  final int seq;

  String get type => event.type;

  /// The player the event is about.
  String? get playerId => (event.data['playerId'] ?? event.data['to'] ?? event.data['target']) as String?;
}

/// The card in the middle of the table and the effect it plays.
@immutable
class StageShot {
  const StageShot({required this.draw, required this.effect, required this.play});

  final LastDraw draw;
  final StageEffect effect;

  /// Changes each time the card should play its arrival. A snap keeps it, so nothing replays.
  final int play;

  @override
  bool operator ==(Object other) =>
      other is StageShot && other.draw.card == draw.card && other.effect == effect && other.play == play;

  @override
  int get hashCode => Object.hash(draw.card, effect, play);
}

@immutable
class TableState {
  const TableState({
    this.shown,
    this.cue,
    this.stage,
    this.arriving = const {},
    this.leaving = const {},
    this.skips = 0,
  });

  /// The view on screen: a few steps behind the server while events play, then exactly the server's.
  final RoomView? shown;

  /// The event being shown now. Null once playback has caught up.
  final TableCue? cue;
  final StageShot? stage;

  /// Cards that fly in from the middle of the table during this beat.
  final Set<String> arriving;

  /// Cards on their way out during this beat: a used Second Chance, or the table clearing.
  final Set<String> leaving;

  /// Bumped when playback skipped ahead, so the table fades to the new state.
  final int skips;
}

class _Beat {
  _Beat(this.event, this.ms, this.batch, this.index);

  final GameEvent event;
  int ms;
  final List<GameEvent> batch;
  final int index;
}

/// Plays the server's events one at a time (PRD §6.3, §9.3).
///
/// Every update brings its events and the full view after them. The events are queued in order,
/// each becomes a beat on screen, and when the queue empties the table snaps to the server's view.
/// Animations only show what the server decided: cards go where its events say, and scores come
/// from its view. Hit/Stay and target choices wait for the beats leading up to them.
class TableDirector extends Notifier<TableState> {
  final _beats = ListQueue<_Beat>();
  RoomView? _target;
  Timer? _timer;
  int _seq = 0;
  int _play = 0;
  String? _myId;

  /// Set from the system "reduce motion" setting: beats get shorter (their effects become fades).
  bool reducedMotion = false;

  /// More waiting than this and older beats are skipped (PRD §6.3).
  static const maxBacklogMs = 5000;

  /// A single update longer than this plays faster instead of being skipped.
  static const maxBatchMs = 6500;

  @override
  TableState build() {
    ref.onDispose(() => _timer?.cancel());
    return const TableState();
  }

  /// A new update from the server. [snap] shows it at once, after joining or reconnecting.
  void receive(RoomView target, List<GameEvent> events, {bool snap = false, String? myId}) {
    _myId = myId ?? _myId;
    final previous = _target;
    _target = target;
    if (snap || state.shown == null) {
      _stop();
      _snapTo(target, events);
      return;
    }

    final beats = _beatsFor(events);
    if (beats.isEmpty) {
      if (_beats.isEmpty && _timer == null) _snapTo(target, events);
      return;
    }
    var batchMs = beats.fold<int>(0, (n, b) => n + b.ms);
    if (reducedMotion) batchMs = _scale(beats, 0.4);
    if (batchMs > maxBatchMs) _scale(beats, maxBatchMs / batchMs);
    final backlog = _beats.fold<int>(0, (n, b) => n + b.ms);
    if (backlog > 0 && backlog + batchMs > maxBacklogMs && previous != null) {
      // Too far behind: jump to where the last update left the table, then play this one.
      _stop();
      _snapTo(previous, const [], skipped: true);
    }
    _beats.addAll(beats);
    if (_timer == null) _advance();
  }

  /// True when everything received has been shown.
  bool get idle => _beats.isEmpty && _timer == null;

  /// Jumps to the server's latest view at once: after coming back to the app (PRD §6.3).
  void skipToEnd() {
    final target = _target;
    if (target == null || (_beats.isEmpty && _timer == null)) return;
    _stop();
    _snapTo(target, const [], skipped: true);
  }

  /// Forgets the table: leaving the room.
  void reset() {
    _stop();
    _target = null;
    state = const TableState();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _beats.clear();
  }

  int _scale(List<_Beat> beats, double factor) {
    var total = 0;
    for (final beat in beats) {
      beat.ms = (beat.ms * factor).round();
      total += beat.ms;
    }
    return total;
  }

  void _advance() {
    _timer = null;
    while (_beats.isNotEmpty) {
      final beat = _beats.removeFirst();
      _apply(beat);
      if (beat.ms > 0) {
        _timer = Timer(Duration(milliseconds: beat.ms), _advance);
        return;
      }
    }
    final target = _target;
    if (target != null) _snapTo(target, const []);
  }

  void _snapTo(RoomView view, List<GameEvent> events, {bool skipped = false}) {
    final draw = view.lastDraw;
    final current = state.stage;
    final stage = draw == null
        ? null
        : StageShot(
            draw: draw,
            effect: stageEffectFor(draw, view.player(draw.playerId)),
            // The same card keeps its token, so a snap never replays its effect.
            play: current != null && current.draw.card == draw.card ? current.play : _play,
          );
    state = TableState(shown: view, stage: stage, skips: state.skips + (skipped ? 1 : 0));
    _observe(view, events);
  }

  void _apply(_Beat beat) {
    final shown = state.shown!;
    final target = _target!;
    final event = beat.event;
    final next = _reduceAndScore(shown, event, target, beat.batch, beat.index);
    var stage = state.stage;
    var arriving = const <String>{};
    var leaving = const <String>{};
    final data = event.data;

    switch (event.type) {
      case 'cardDealt':
        final card = GameCard.fromJson(data['card'] as Map<String, dynamic>);
        stage = StageShot(draw: next.lastDraw!, effect: _stageEffect(card, beat), play: ++_play);
        final duplicate = card.isNumber && _duplicateOutcome(beat.batch, beat.index, card.id) != null;
        if (!card.isAction && !duplicate) arriving = {card.id};
      case 'busted':
        arriving = {_card(data['duplicate']).id};
      case 'secondChanceKept' || 'secondChanceGiven':
        arriving = {_card(data['card']).id};
      case 'secondChanceUsed':
        leaving = {_card(data['card']).id};
      case 'roundStarted':
        leaving = {
          for (final p in shown.players) ...[
            ...p.row.map((c) => c.id),
            ...p.modifiers.map((c) => c.id),
            if (p.secondChance != null) p.secondChance!.id,
            if (p.bustCard != null) p.bustCard!.id,
          ],
        };
    }
    state = TableState(
      shown: next,
      cue: TableCue(event, ++_seq),
      stage: event.type == 'roundStarted' ? null : stage,
      arriving: arriving,
      leaving: leaving,
      skips: state.skips,
    );
    _observe(next, [event]);
  }

  /// Tutorial tips follow what's on screen, not what's still queued (PRD §4.9).
  void _observe(RoomView view, List<GameEvent> events) {
    if (!view.tutorial) return;
    ref.read(tutorialCoachProvider.notifier).observe(view, events, _myId);
  }

  StageEffect _stageEffect(GameCard card, _Beat beat) {
    switch (card.kind) {
      case CardKind.freeze:
        return StageEffect.freeze;
      case CardKind.flipThree:
        return StageEffect.flipThree;
      case CardKind.secondChance:
        return StageEffect.secondChance;
      case CardKind.plus || CardKind.x2:
        return StageEffect.modifier;
      case CardKind.number:
        final outcome = _duplicateOutcome(beat.batch, beat.index, card.id);
        if (outcome == 'busted') return StageEffect.bust;
        if (outcome == 'secondChanceUsed') return StageEffect.saved;
        final next = beat.index + 1 < beat.batch.length ? beat.batch[beat.index + 1] : null;
        return next?.type == 'seventhCard' ? StageEffect.seventh : StageEffect.plain;
    }
  }

  List<_Beat> _beatsFor(List<GameEvent> events) {
    final beats = <_Beat>[];
    for (var i = 0; i < events.length; i++) {
      final ms = beatMs(events, i);
      if (ms == null) continue;
      beats.add(_Beat(events[i], ms, events, i));
      if (events[i].type == 'secondChanceUsed') {
        // The used Second Chance plays its exit, then leaves the row.
        beats.add(_Beat(GameEvent('_secondChanceGone', events[i].data), 0, events, i));
      }
      if (events[i].type == 'roundStarted') {
        beats.add(_Beat(const GameEvent('_tableCleared', {}), 0, events, i));
      }
    }
    return beats;
  }
}

GameCard _card(Object? json) => GameCard.fromJson(json! as Map<String, dynamic>);

/// How a number card revealed at [index] turns out, from the events after it: `busted`,
/// `secondChanceUsed`, or null when it simply joins the row.
String? _duplicateOutcome(List<GameEvent> batch, int index, String cardId) {
  for (var i = index + 1; i < batch.length; i++) {
    final e = batch[i];
    if (e.type == 'cardDealt') return null;
    if ((e.type == 'busted' || e.type == 'secondChanceUsed') &&
        (e.data['duplicate'] as Map<String, dynamic>?)?['id'] == cardId) {
      return e.type;
    }
  }
  return null;
}

/// How long the table spends on the event at [index] (PRD §6.3), or null for events with nothing
/// to show on the table (they appear when playback catches up).
@visibleForTesting
int? beatMs(List<GameEvent> batch, int index) {
  final event = batch[index];
  final data = event.data;
  switch (event.type) {
    case 'cardDealt':
      final card = _card(data['card']);
      if (card.isAction) return AppMotion.beatAction.inMilliseconds;
      if (!card.isNumber) return AppMotion.beatModifier.inMilliseconds;
      if (_duplicateOutcome(batch, index, card.id) != null) return AppMotion.beatDuplicate.inMilliseconds;
      return switch (data['source']) {
        'deal' => AppMotion.beatDeal.inMilliseconds,
        'flipThree' => AppMotion.beatFlipThree.inMilliseconds,
        _ => AppMotion.beatHit.inMilliseconds,
      };
    case 'busted':
      return AppMotion.bust.inMilliseconds;
    case 'secondChanceUsed':
      return AppMotion.secondChance.inMilliseconds;
    case 'frozen':
      return AppMotion.freeze.inMilliseconds;
    case 'stayed' || 'autoStayed':
      return AppMotion.stay.inMilliseconds;
    case 'seventhCard':
      return AppMotion.seventhCard.inMilliseconds;
    case 'actionPlayed' || 'secondChanceGiven' || 'flipThreeStarted':
      return AppMotion.beatTarget.inMilliseconds;
    case 'secondChanceKept' || 'secondChanceDiscarded':
      return AppMotion.beatShort.inMilliseconds;
    case 'reshuffled':
      return AppMotion.reshuffle.inMilliseconds;
    case 'extraDeckAdded':
      return AppMotion.extraDeck.inMilliseconds;
    case 'roundStarted':
      return AppMotion.beatClear.inMilliseconds;
    case 'turnStarted':
      return data['forced'] == true ? AppMotion.beatShort.inMilliseconds : 0;
    case 'roundScored':
      // The last round of a game gets a moment for its scores before the results.
      return batch.skip(index).any((e) => e.type == 'gameOver') ? AppMotion.beatFinalRound.inMilliseconds : 0;
    case 'decisionRequested' ||
        'flipThreeEnded' ||
        'autoHit' ||
        'tiebreakStarted' ||
        'deckReset' ||
        'gameStarted' ||
        'playerDisconnected' ||
        'playerReconnected' ||
        'playerLeft':
      return 0;
    default:
      return null;
  }
}

/// [reduceView], then: once a player's cards on screen match the server's, their round score is
/// the server's too, so it never waits for the whole update (and is never computed here).
RoomView _reduceAndScore(RoomView v, GameEvent event, RoomView target, List<GameEvent> batch, int index) {
  final next = reduceView(v, event, target, batch, index);
  final playerId = (event.data['playerId'] ?? event.data['to']) as String?;
  final shown = next.player(playerId);
  final truth = target.player(playerId);
  if (shown == null || truth == null || shown.roundScore == truth.roundScore) return next;
  bool same(List<GameCard> a, List<GameCard> b) => a.length == b.length && a.every(b.contains);
  final matches =
      same(shown.row, truth.row) &&
      same(shown.modifiers, truth.modifiers) &&
      shown.bustCard == truth.bustCard &&
      shown.status == truth.status;
  return matches ? next.withPlayer(playerId!, (p) => p.copyWith(roundScore: truth.roundScore)) : next;
}

/// The view after [event], built from the event's own data. Cards go where the server's events say
/// (a duplicate goes nowhere until its `busted` or `secondChanceUsed`), and anything the events
/// don't say comes from [target], the server's latest view. Scores are never computed here: round
/// scores update when playback catches up to the server's view.
@visibleForTesting
RoomView reduceView(RoomView v, GameEvent event, RoomView target, List<GameEvent> batch, int index) {
  final data = event.data;
  String? id(String key) => data[key] as String?;
  List<String> ids(String key) => (data[key] as List<dynamic>? ?? const []).cast<String>();

  switch (event.type) {
    case 'roundStarted':
      final playing = ids('playerIds');
      final tiebreak = data['tiebreak'] as Map<String, dynamic>?;
      return v.copyWith(
        phase: Phase.dealing,
        round: data['round'] as int,
        roundPlayerIds: playing,
        dealerId: id('dealerId'),
        turnPlayerId: id('dealerId'),
        tiebreak: tiebreak == null
            ? null
            : Tiebreak(roundNo: tiebreak['roundNo'] as int, playerIds: (tiebreak['playerIds'] as List).cast<String>()),
        decision: null,
        flipThrees: const [],
        nextRoundAt: null,
        scoredTiebreakRound: null,
      );
    case '_tableCleared':
      final playing = v.roundPlayerIds;
      return v.copyWith(
        lastDraw: null,
        players: [
          for (final p in v.players)
            p.copyWith(
              status: p.status == PlayerStatus.left
                  ? PlayerStatus.left
                  : (playing.contains(p.id) ? PlayerStatus.active : PlayerStatus.watching),
              row: const [],
              modifiers: const [],
              secondChance: null,
              played: const [],
              bustCard: null,
              seventhCard: false,
              roundScore: 0,
              forced: target.player(p.id)?.forced ?? false,
            ),
        ],
      );
    case 'cardDealt':
      final to = id('to')!;
      final card = _card(data['card']);
      final source = switch (data['source']) {
        'hit' => DrawSource.hit,
        'flipThree' => DrawSource.flipThree,
        _ => DrawSource.deal,
      };
      var next = v.copyWith(
        lastDraw: LastDraw(card: card, playerId: to, source: source),
        // A hit answers the open decision.
        decision: source == DrawSource.hit ? null : v.decision,
      );
      if (source == DrawSource.flipThree) {
        next = next.copyWith(
          flipThrees: [
            for (final f in next.flipThrees)
              f.playerId == to ? FlipThreeProgress(playerId: to, remaining: math.max(0, f.remaining - 1)) : f,
          ],
        );
      }
      if (card.isNumber) {
        if (_duplicateOutcome(batch, index, card.id) == null) {
          next = next.withPlayer(to, (p) => p.copyWith(row: [...p.row, card]));
        }
      } else if (!card.isAction) {
        next = next.withPlayer(to, (p) => p.copyWith(modifiers: [...p.modifiers, card]));
      }
      return next;
    case 'turnStarted':
      return v.copyWith(phase: Phase.turns, turnPlayerId: id('playerId'), decision: null);
    case 'decisionRequested':
      return v.copyWith(decision: Decision.fromJson(data['decision'] as Map<String, dynamic>));
    case 'actionPlayed':
      return v
          .copyWith(decision: null)
          .withPlayer(id('by')!, (p) => p.copyWith(played: [...p.played, _card(data['card'])]));
    case 'frozen':
      return v.withPlayer(id('playerId')!, (p) => p.copyWith(status: PlayerStatus.frozen));
    case 'flipThreeStarted':
      final playerId = id('playerId')!;
      final remaining = data['remaining'] as int;
      final top = v.flipThrees.isEmpty ? null : v.flipThrees.last;
      return v.copyWith(
        flipThrees: top?.playerId == playerId
            ? [
                ...v.flipThrees.take(v.flipThrees.length - 1),
                FlipThreeProgress(playerId: playerId, remaining: remaining),
              ]
            : [...v.flipThrees, FlipThreeProgress(playerId: playerId, remaining: remaining)],
      );
    case 'flipThreeEnded':
      final playerId = id('playerId');
      final at = v.flipThrees.lastIndexWhere((f) => f.playerId == playerId);
      return at < 0 ? v : v.copyWith(flipThrees: [...v.flipThrees]..removeAt(at));
    case 'secondChanceKept':
      return v.withPlayer(id('playerId')!, (p) => p.copyWith(secondChance: _card(data['card'])));
    case 'secondChanceGiven':
      return v.copyWith(decision: null).withPlayer(id('to')!, (p) => p.copyWith(secondChance: _card(data['card'])));
    case 'secondChanceDiscarded':
      return v.copyWith(decision: null);
    case '_secondChanceGone':
      return v.withPlayer(id('playerId')!, (p) => p.copyWith(secondChance: null));
    case 'stayed' || 'autoStayed':
      return v.copyWith(decision: null).withPlayer(id('playerId')!, (p) => p.copyWith(status: PlayerStatus.stayed));
    case 'autoHit':
      return v.copyWith(decision: null);
    case 'busted':
      return v.withPlayer(
        id('playerId')!,
        (p) => p.copyWith(status: PlayerStatus.busted, bustCard: _card(data['duplicate'])),
      );
    case 'seventhCard':
      return v.withPlayer(id('playerId')!, (p) => p.copyWith(seventhCard: true));
    case 'roundScored':
      final scores = {
        for (final s in (data['scores'] as List<dynamic>).cast<Map<String, dynamic>>()) s['playerId'] as String: s,
      };
      return v.copyWith(
        phase: Phase.roundOver,
        decision: null,
        turnPlayerId: null,
        flipThrees: const [],
        nextRoundAt: target.nextRoundAt,
        scoredTiebreakRound: target.scoredTiebreakRound,
        players: [
          for (final p in v.players)
            scores[p.id] == null
                ? p
                : p.copyWith(roundScore: scores[p.id]!['roundScore'] as int, total: scores[p.id]!['total'] as int),
        ],
      );
    case 'tiebreakStarted':
      return v.copyWith(
        tiebreak: Tiebreak(roundNo: data['roundNo'] as int, playerIds: ids('playerIds')),
      );
    case 'playerDisconnected' || 'playerReconnected' || 'playerLeft':
      final playerId = id('playerId');
      final now = target.player(playerId);
      if (now == null || v.player(playerId) == null) return v;
      return v.withPlayer(playerId!, (p) => p.copyWith(connected: now.connected, status: now.status));
    default:
      return v;
  }
}

final tableDirectorProvider = NotifierProvider<TableDirector, TableState>(TableDirector.new);

/// The view the game screens draw: the director's, or the room's when nothing has played yet
/// (the screen gallery and widget tests set the room directly).
final tableViewProvider = Provider<RoomView?>(
  (ref) => ref.watch(tableDirectorProvider.select((s) => s.shown)) ?? ref.watch(roomProvider.select((s) => s.view)),
);

/// This player's open decision, once the beats leading up to it have played (PRD §9.3). Null if
/// the server has already moved on, or the player has just answered it.
final myDecisionProvider = Provider<Decision?>((ref) {
  final shown = ref.watch(tableViewProvider);
  final room = ref.watch(roomProvider);
  final decision = shown?.decision;
  if (decision == null || decision.playerId != room.playerId) return null;
  if (shown!.phase != Phase.dealing && shown.phase != Phase.turns) return null;
  if (room.view?.decision?.id != decision.id || room.pendingDecisionId == decision.id) return null;
  return decision;
});
