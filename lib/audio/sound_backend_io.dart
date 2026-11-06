import 'package:audioplayers/audioplayers.dart';

import 'sound_backend.dart';

/// iOS and Android: a small pool of players per sound, so quick repeats (a deal) overlap.
class PlatformSoundBackend implements SoundBackend {
  final _pools = <String, AudioPool>{};

  @override
  Future<void> preload(Map<String, String> assets) async {
    for (final MapEntry(key: name, value: path) in assets.entries) {
      if (_pools.containsKey(name)) continue;
      try {
        _pools[name] = await AudioPool.create(
          source: AssetSource(path.replaceFirst('assets/', '')),
          maxPlayers: 3,
          playerMode: PlayerMode.lowLatency,
        );
      } catch (_) {
        // A missing or broken sound must never stop the game.
      }
    }
  }

  @override
  void play(String name, {double volume = 1}) {
    _pools[name]?.start(volume: volume).catchError((_) => () async {});
  }
}
