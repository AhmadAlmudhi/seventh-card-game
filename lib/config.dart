import 'package:flutter/foundation.dart';

/// Build-time settings, passed with `--dart-define`.
abstract final class AppConfig {
  static const _serverUrl = String.fromEnvironment('SERVER_URL');
  static const _defaultServerUrl = 'wss://seventh-card-server.ahmadalmudhi.workers.dev';

  /// The room server's WebSocket base URL (PRD §8.5.1).
  static String get serverUrl => _serverUrl.isEmpty ? _defaultServerUrl : _serverUrl;

  /// The same server over HTTP(S), for creating rooms.
  static String get httpBase => serverUrl.replaceFirst(RegExp('^ws'), 'http');

  /// The language the app opens in before the player picks one. Arabic is the default (PRD §6.6).
  /// Pass `--dart-define=LOCALE=en` to preview English.
  static const String initialLocale = String.fromEnvironment('LOCALE', defaultValue: 'ar');

  static const _appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://ahmadalmudhi.github.io/seventh-card-game/',
  );

  /// A shareable link that opens a room (PRD §4.3). On the web it points at wherever the app is
  /// running, so local builds share local links.
  static String roomLink(String code) {
    if (kIsWeb) return '${Uri.base.origin}${Uri.base.path}#/room/$code';
    return '$_appUrl#/room/$code';
  }
}
