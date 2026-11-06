import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'sound_backend.dart';

/// Browsers: the Web Audio API. Sounds are decoded once and played with no delay. Phones only let
/// a page make sound after the player touches it, so the first tap anywhere unlocks the audio.
class PlatformSoundBackend implements SoundBackend {
  web.AudioContext? _context;
  final _buffers = <String, web.AudioBuffer>{};
  bool _listening = false;

  web.AudioContext? get _ctx {
    if (_context != null) return _context;
    try {
      _context = web.AudioContext();
    } catch (_) {
      return null; // No Web Audio: the game stays silent.
    }
    _unlockOnFirstTouch();
    return _context;
  }

  void _unlockOnFirstTouch() {
    if (_listening) return;
    _listening = true;
    void resume(web.Event _) {
      final ctx = _context;
      if (ctx != null && ctx.state != 'running') ctx.resume();
    }

    for (final type in ['pointerdown', 'touchend', 'keydown']) {
      web.document.addEventListener(type, resume.toJS, web.AddEventListenerOptions(capture: true));
    }
  }

  @override
  Future<void> preload(Map<String, String> assets) async {
    final ctx = _ctx;
    if (ctx == null) return;
    for (final MapEntry(key: name, value: path) in assets.entries) {
      if (_buffers.containsKey(name)) continue;
      try {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        // decodeAudioData takes ownership of the buffer, so give it a copy.
        final buffer = await ctx.decodeAudioData(Uint8List.fromList(bytes).buffer.toJS).toDart;
        _buffers[name] = buffer;
      } catch (_) {
        // A missing or undecodable sound must never stop the game.
      }
    }
  }

  @override
  void play(String name, {double volume = 1}) {
    final ctx = _context;
    final buffer = _buffers[name];
    if (ctx == null || buffer == null) return;
    if (ctx.state != 'running') {
      ctx.resume();
      return; // Still locked: the player hasn't touched the page yet.
    }
    final source = ctx.createBufferSource()..buffer = buffer;
    final gain = ctx.createGain();
    gain.gain.value = volume;
    source.connect(gain);
    gain.connect(ctx.destination);
    source.start();
  }
}
