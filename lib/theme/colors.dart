import 'dart:ui';

/// The app's single color palette (PRD §6.1). There is no dark or light variant.
///
/// Provisional M0 values. The full palette, including the 13 number colors, is
/// designed in M3. `web/index.html` repeats [table] and [onTable] for the
/// loading screen, so keep them in sync.
abstract final class AppColors {
  /// Deep table felt: the background of every screen.
  static const table = Color(0xFF0B3B2E);

  /// Main text and marks on [table]. Contrast on [table]: about 10.7:1.
  static const onTable = Color(0xFFF6EEDF);

  /// Secondary text on [table]. Contrast on [table]: about 6:1 (WCAG AA).
  static const onTableMuted = Color(0xFFB0B8AA);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
}
