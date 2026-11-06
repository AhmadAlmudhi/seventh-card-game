/// Build-time settings, passed with `--dart-define`.
abstract final class AppConfig {
  /// The language the app opens in. Arabic is the default (PRD §6.6).
  ///
  /// Pass `--dart-define=LOCALE=en` to preview English. Once the Home screen's
  /// language toggle exists (M3), the saved choice takes priority over this.
  static const String locale = String.fromEnvironment('LOCALE', defaultValue: 'ar');
}
