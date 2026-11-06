import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/protocol.dart';

/// The tutorial's tips (PRD §4.9), each shown once, the first time it's useful.
enum CoachTip { welcome, turn, risk, bust, freeze, flipThree, secondChance, modifier, seventh }

@immutable
class CoachState {
  const CoachState({this.seen = const {}, this.queue = const []});

  /// Tips already shown (or queued), so none repeats, even after Play again.
  final Set<CoachTip> seen;

  /// Tips waiting to be shown, oldest first. The first one is on screen.
  final List<CoachTip> queue;

  CoachTip? get current => queue.isEmpty ? null : queue.first;
}

/// Watches the tutorial game and queues a tip when something happens for the first time. It only
/// reads the view the server sent: it explains what happened, it never decides it.
class TutorialCoach extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  /// Looks at the latest view and its events for moments worth a tip.
  void observe(RoomView view, List<GameEvent> events, String? myId) {
    if (!view.tutorial || !view.isPlaying) return;
    final found = <CoachTip>[CoachTip.welcome];
    final decision = view.decision;
    final mine = decision != null && decision.playerId == myId;
    final me = view.player(myId);
    if (mine && decision.kind == DecisionKind.hitOrStay) {
      found.add(CoachTip.turn);
      if ((me?.row.length ?? 0) >= 2) found.add(CoachTip.risk);
    }
    final card = view.lastDraw?.card;
    switch (card?.kind) {
      case CardKind.freeze:
        found.add(CoachTip.freeze);
      case CardKind.flipThree:
        found.add(CoachTip.flipThree);
      case CardKind.secondChance:
        found.add(CoachTip.secondChance);
      case CardKind.plus || CardKind.x2:
        found.add(CoachTip.modifier);
      case CardKind.number || null:
        break;
    }
    if (events.any((e) => e.type == 'busted') || view.players.any((p) => p.status == PlayerStatus.busted)) {
      found.add(CoachTip.bust);
    }
    if (events.any((e) => e.type == 'seventhCard')) found.add(CoachTip.seventh);

    final fresh = found.where((tip) => !state.seen.contains(tip)).toList();
    if (fresh.isEmpty) return;
    state = CoachState(seen: {...state.seen, ...fresh}, queue: [...state.queue, ...fresh]);
  }

  /// "Got it": shows the next waiting tip, if any.
  void dismiss() {
    if (state.queue.isEmpty) return;
    state = CoachState(seen: state.seen, queue: state.queue.sublist(1));
  }

  /// A new tutorial from Home starts with every tip again.
  void reset() => state = const CoachState();
}

final tutorialCoachProvider = NotifierProvider<TutorialCoach, CoachState>(TutorialCoach.new);
