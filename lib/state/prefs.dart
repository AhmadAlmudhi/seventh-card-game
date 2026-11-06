import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The room a player is in, so they can reconnect after a restart (PRD §9.4).
class Session {
  const Session({required this.roomCode, required this.token, this.tutorial = false});

  final String roomCode;
  final String token;

  /// A tutorial room (PRD §4.9), so Home can offer "Back to the tutorial".
  final bool tutorial;
}

/// Everything saved on the device (PRD §9.4).
class Prefs {
  Prefs(this._prefs);

  final SharedPreferences _prefs;

  String get nickname => _prefs.getString('nickname') ?? '';
  Future<void> setNickname(String value) => _prefs.setString('nickname', value);

  Session? get session {
    final raw = _prefs.getString('session');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Session(
        roomCode: json['roomCode'] as String,
        token: json['token'] as String,
        tutorial: json['tutorial'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setSession(Session? session) => session == null
      ? _prefs.remove('session')
      : _prefs.setString(
          'session',
          jsonEncode({'roomCode': session.roomCode, 'token': session.token, if (session.tutorial) 'tutorial': true}),
        );

  bool get soundOn => _prefs.getBool('soundOn') ?? true;
  Future<void> setSoundOn(bool value) => _prefs.setBool('soundOn', value);

  String? get language => _prefs.getString('language');
  Future<void> setLanguage(String value) => _prefs.setString('language', value);

  /// A random id made the first time the app opens and kept for good. The server uses it only to
  /// keep players the host removed from rejoining (PRD §8.5).
  String get deviceId {
    final existing = _prefs.getString('deviceId');
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _prefs.setString('deviceId', id);
    return id;
  }
}

/// Overridden in `main()` once SharedPreferences has loaded.
final prefsProvider = Provider<Prefs>((ref) => throw UnimplementedError('prefsProvider must be overridden'));
