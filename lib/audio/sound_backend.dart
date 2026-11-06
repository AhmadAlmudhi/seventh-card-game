/// Plays short sound effects. One implementation per platform (PRD §6.4).
abstract class SoundBackend {
  /// Loads every sound up front, so the first one plays without a delay.
  Future<void> preload(Map<String, String> assets);

  /// Plays a loaded sound. Does nothing if it isn't loaded yet.
  void play(String name, {double volume = 1});
}
