// End to end: three copies of the app's room controller play a full game against a real server,
// over real WebSockets. Off by default; run it against `npm run dev` in server/:
//
//   flutter test test/e2e/live_game_test.dart --dart-define=E2E=true --dart-define=SERVER_URL=ws://localhost:8787
@Tags(['e2e'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/net/protocol.dart';
import 'package:seventh_card_game/net/room_api.dart';
import 'package:seventh_card_game/state/prefs.dart';
import 'package:seventh_card_game/state/room_controller.dart';

const _enabled = bool.fromEnvironment('E2E');

void main() {
  // No widgets binding here on purpose: flutter_test's binding blocks real network access.
  test(
    'three players finish a game against the real server, then return to the room',
    () async {
      final code = await RoomApi().createRoom();

      // Each player is a separate device, with its own saved data. (On one real device, a second
      // copy of the app would reconnect as the same player, by design.)
      final players = [
        for (var i = 0; i < 3; i++)
          ProviderContainer(overrides: [prefsProvider.overrideWithValue(_MemoryPrefs('e2e-device-$i-0000000000'))]),
      ];
      addTearDown(() {
        for (final p in players) {
          p.dispose();
        }
      });
      const names = ['Ali', 'سارة', 'Omar'];

      final trace = <String>[];
      for (var i = 0; i < players.length; i++) {
        players[i].listen(roomProvider, (_, s) {
          trace.add(
            'p$i ${s.status.name} v${s.version} ${s.view?.phase.name ?? '-'} err=${s.error} notice=${s.notice?.code}',
          );
        });
      }
      addTearDown(() {
        // ignore: avoid_print
        if (trace.isNotEmpty) print('last states:\n${trace.reversed.take(12).toList().reversed.join('\n')}');
      });

      Future<RoomState> waitFor(
        ProviderContainer c,
        bool Function(RoomState s) condition, {
        Duration timeout = const Duration(seconds: 20),
      }) {
        final completer = Completer<RoomState>();
        final sub = c.listen(roomProvider, (_, s) {
          if (!completer.isCompleted && condition(s)) completer.complete(s);
        }, fireImmediately: true);
        return completer.future.timeout(timeout).whenComplete(sub.close);
      }

      for (var i = 0; i < players.length; i++) {
        await players[i].read(roomProvider.notifier).enter(code, names[i]);
        await waitFor(players[i], (s) => s.status == LinkStatus.connected && s.view != null);
      }
      await waitFor(players[0], (s) => s.view?.players.length == 3);

      // Every bot answers its own decisions, the way a player would, a moment after they appear.
      final subscriptions = <ProviderSubscription<RoomState>>[];
      for (final p in players) {
        subscriptions.add(
          p.listen(roomProvider, (_, s) {
            final decision = s.myDecision;
            if (decision == null) return;
            Timer(const Duration(milliseconds: 120), () {
              final current = p.read(roomProvider);
              if (current.myDecision?.id != decision.id) return;
              final controller = p.read(roomProvider.notifier);
              if (decision.kind == DecisionKind.hitOrStay) {
                final cards = current.me?.row.length ?? 0;
                decision.canStay && cards >= 3 ? controller.stay() : controller.hit();
              } else {
                controller.choose(
                  decision.targets.firstWhere((id) => id != current.playerId, orElse: () => decision.targets.first),
                );
              }
            });
          }),
        );
      }
      addTearDown(() {
        for (final s in subscriptions) {
          s.close();
        }
      });

      final host = players[0].read(roomProvider.notifier);
      host.changeSettings(GameMode.normal, 100);
      await waitFor(players[0], (s) => s.view?.targetScore == 100);
      host.start();

      // A real game has a 4-second break between rounds, so it takes a while.
      final results = await waitFor(
        players[0],
        (s) => s.view?.phase == Phase.results,
        timeout: const Duration(minutes: 3),
      );
      final view = results.view!;
      expect(view.outcome?.winnerIds, isNotEmpty);
      expect(view.players.map((p) => p.total).reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(100));
      // Every client sees the same final state (each copy of the update arrives separately).
      for (final p in players) {
        final theirs = await waitFor(p, (s) => s.view?.phase == Phase.results);
        expect(theirs.view?.outcome?.winnerIds, view.outcome?.winnerIds);
      }

      for (final p in players) {
        p.read(roomProvider.notifier).continueToRoom();
      }
      await waitFor(players[0], (s) => s.view?.phase == Phase.lobby);
      // ignore: avoid_print
      print('room $code: game over after round ${view.round}; winner ${view.outcome?.winnerIds}');
    },
    skip: _enabled ? false : 'end-to-end: pass --dart-define=E2E=true and SERVER_URL (see the top of this file)',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// Saved data for one simulated device, kept in memory.
class _MemoryPrefs implements Prefs {
  _MemoryPrefs(this.deviceId);

  @override
  final String deviceId;
  @override
  String nickname = '';
  @override
  Session? session;
  @override
  bool soundOn = true;
  @override
  String? language;

  @override
  Future<void> setNickname(String value) async => nickname = value;
  @override
  Future<void> setSession(Session? value) async => session = value;
  @override
  Future<void> setSoundOn(bool value) async => soundOn = value;
  @override
  Future<void> setLanguage(String value) async => language = value;
}
