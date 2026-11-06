import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings.dart';
import 'sound_backend.dart';
import 'sound_backend_io.dart' if (dart.library.js_interop) 'sound_backend_web.dart';

/// The game's sound effects (PRD §6.4). Files are in `assets/sounds/`: Kenney's CC0 casino and
/// interface packs, plus bell chimes made for this game.
enum Sfx { deal, flip, action, bust, freeze, saved, stay, bonus, tick, roundEnd, shuffle, turn, seventh, win }

/// Haptic patterns (PRD §6.4): your turn, bust, Seventh Card and the last seconds of the timer.
enum Buzz { turn, bust, seventh, tick }

const _files = {
  'deal1': 'assets/sounds/deal1.m4a',
  'deal2': 'assets/sounds/deal2.m4a',
  'deal3': 'assets/sounds/deal3.m4a',
  'flip': 'assets/sounds/flip.m4a',
  'action': 'assets/sounds/action.m4a',
  'bust': 'assets/sounds/bust.m4a',
  'freeze': 'assets/sounds/freeze.m4a',
  'saved': 'assets/sounds/saved.m4a',
  'stay': 'assets/sounds/stay.m4a',
  'bonus': 'assets/sounds/bonus.m4a',
  'tick': 'assets/sounds/tick.m4a',
  'round_end': 'assets/sounds/round_end.m4a',
  'shuffle': 'assets/sounds/shuffle.m4a',
  'turn': 'assets/sounds/turn.m4a',
  'seventh': 'assets/sounds/seventh.m4a',
  'win': 'assets/sounds/win.m4a',
};

/// Sound effects and haptics, both following the sound toggle.
class GameFeedback {
  GameFeedback(this._ref, [SoundBackend? backend]) : _backend = backend ?? PlatformSoundBackend();

  final Ref _ref;
  final SoundBackend _backend;
  final _random = Random();
  Future<void>? _loading;

  bool get _on => _ref.read(soundProvider);

  /// Loads every sound; safe to call more than once. Called when a room opens.
  Future<void> preload() => _loading ??= _backend.preload(_files);

  void play(Sfx sfx) {
    if (!_on) return;
    final (name, volume) = switch (sfx) {
      // Three deal sounds in turn, so a fast deal doesn't sound mechanical.
      Sfx.deal => ('deal${_random.nextInt(3) + 1}', 0.8),
      Sfx.flip => ('flip', 0.7),
      Sfx.action => ('action', 0.8),
      Sfx.bust => ('bust', 0.9),
      Sfx.freeze => ('freeze', 0.8),
      Sfx.saved => ('saved', 0.8),
      Sfx.stay => ('stay', 0.8),
      Sfx.bonus => ('bonus', 0.7),
      Sfx.tick => ('tick', 0.6),
      Sfx.roundEnd => ('round_end', 0.7),
      Sfx.shuffle => ('shuffle', 0.7),
      Sfx.turn => ('turn', 0.8),
      Sfx.seventh => ('seventh', 0.9),
      Sfx.win => ('win', 0.9),
    };
    _backend.play(name, volume: volume);
  }

  void buzz(Buzz buzz) {
    if (!_on) return;
    switch (buzz) {
      case Buzz.turn:
        HapticFeedback.mediumImpact();
      case Buzz.bust:
        HapticFeedback.heavyImpact();
      case Buzz.seventh:
        HapticFeedback.heavyImpact();
      case Buzz.tick:
        HapticFeedback.selectionClick();
    }
  }
}

final gameFeedbackProvider = Provider<GameFeedback>((ref) => GameFeedback(ref));
