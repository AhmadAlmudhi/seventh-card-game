/// Spacing scale. Use these instead of literal numbers in widgets.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal padding of every screen.
  static const double screen = 24;

  /// The widest a phone-style layout grows on tablets and desktops.
  static const double maxContentWidth = 520;

  /// Minimum touch target (PRD §6.5).
  static const double minTouch = 48;
}

/// Corner radii.
abstract final class AppRadii {
  static const double chip = 20;
  static const double field = 16;
  static const double button = 18;
  static const double panel = 18;
  static const double sheet = 28;

  /// Card corners, as a fraction of the card's width.
  static const double cardFraction = 0.16;
}
