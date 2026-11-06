import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import 'prefs.dart';

/// The app's language. Arabic until the player picks otherwise; the choice is remembered (PRD §4.1).
class LanguageController extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(prefsProvider).language ?? AppConfig.initialLocale);

  void set(Locale locale) {
    state = locale;
    ref.read(prefsProvider).setLanguage(locale.languageCode);
  }
}

final languageProvider = NotifierProvider<LanguageController, Locale>(LanguageController.new);

/// Sound effects on or off. On by default; the choice is remembered (PRD §6.4).
class SoundController extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).soundOn;

  void toggle() {
    state = !state;
    ref.read(prefsProvider).setSoundOn(state);
  }
}

final soundProvider = NotifierProvider<SoundController, bool>(SoundController.new);

/// The nickname typed on the Home screen, remembered on the device (PRD §4.1).
class NicknameController extends Notifier<String> {
  @override
  String build() => ref.read(prefsProvider).nickname;

  void set(String value) {
    state = value;
    ref.read(prefsProvider).setNickname(value);
  }
}

final nicknameProvider = NotifierProvider<NicknameController, String>(NicknameController.new);
