import 'dart:ui';

/// The app's single color palette: "Felt & Gold" (PRD §6.1). There is no dark or light variant.
///
/// `web/index.html` repeats [table] and [onTable] for the loading screen, so keep them in sync.
abstract final class AppColors {
  // Table and surfaces
  /// Deep table felt: the background of every screen.
  static const table = Color(0xFF0D3B2E);

  /// The lighter centre of the felt's radial glow.
  static const tableLight = Color(0xFF175A45);

  /// Panels, fields and seats on the felt.
  static const panel = Color(0xFF0A2F25);
  static const panelBorder = Color(0xFF2A5E4F);

  /// Secondary buttons and quiet fills.
  static const secondary = Color(0xFF184638);

  // Text
  /// Main text on the felt. Contrast on [table]: 10.8:1.
  static const onTable = Color(0xFFF6EEDF);

  /// Secondary text on the felt. Contrast on [table]: 6.1:1.
  static const onTableMuted = Color(0xFFB0B8AA);

  // Accents
  /// Primary actions, highlights and the brand gold.
  static const gold = Color(0xFFE9B949);

  /// Text and icons on [gold]. Contrast: 8.9:1.
  static const onGold = Color(0xFF2A1E05);
  static const danger = Color(0xFFE5534B);
  static const success = Color(0xFF6FCF97);
  static const info = Color(0xFF7FD3F5);

  // Cards
  static const cardFace = Color(0xFFFFFFFF);
  static const cardEdge = Color(0xFFE4DED2);
  static const cardBack = Color(0xFF12493A);
  static const cardBackInk = gold;
  static const modifierFace = Color(0xFFF3D58A);
  static const modifierInk = Color(0xFF4A3505);
  static const actionFace = Color(0xFF123A30);
  static const freeze = Color(0xFF7FD3F5);
  static const flipThree = Color(0xFFF2994A);
  static const secondChance = Color(0xFF6FCF97);

  /// Number card bands, by value 0–12, on a green-to-red risk scale. Each number has as many copies
  /// as its value (0 has one), so holding a high number makes a duplicate, and a bust, more likely:
  /// green for the singletons (0 and 1) through yellow and orange to crimson for the twelve 12s.
  /// The printed number stays the main signal (PRD §6.5).
  static const numberBands = <Color>[
    Color(0xFF22B35E), Color(0xFF22B35E), Color(0xFF4CBF4F), Color(0xFF86C93A), Color(0xFFB5CF2B), //
    Color(0xFFE0CB1F), Color(0xFFF5B820), Color(0xFFF79E22), Color(0xFFF5841F), Color(0xFFF06A26), //
    Color(0xFFE8502E), Color(0xFFDC3737), Color(0xFFC2223F),
  ];

  /// Numerals on number cards: the band's hue, deepened to at least 4.5:1 on [cardFace].
  static const numberInks = <Color>[
    Color(0xFF028742), Color(0xFF028742), Color(0xFF028818), Color(0xFF4F8202), Color(0xFF6B7C03), //
    Color(0xFF907101), Color(0xFF956E03), Color(0xFFA56602), Color(0xFFB45D06), Color(0xFFC74F06), //
    Color(0xFFD63E1B), Color(0xFFDA3535), Color(0xFFC2223F),
  ];

  static const shadow = Color(0x55000000);
  static const scrim = Color(0xB3061C16);

  static const errorContainer = Color(0xFFFFB4AB);
  static const onErrorContainer = Color(0xFF690005);
}
