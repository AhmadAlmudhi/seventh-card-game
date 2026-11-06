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

  /// Number card bands, by value 0–12. Colored by how many copies of the number are in the deck:
  /// gold for the singletons (0 and 1), deepening through orange, rose and violet to sapphire for
  /// the twelve 12s. Lightness falls steadily, so the order survives color blindness.
  static const numberBands = <Color>[
    Color(0xFFF4BB0E), Color(0xFFF4BB0E), Color(0xFFF8A309), Color(0xFFF98C1E), Color(0xFFF57640), //
    Color(0xFFEA635B), Color(0xFFDA5371), Color(0xFFC74881), Color(0xFFAF4191), Color(0xFF923DA0), //
    Color(0xFF723BA8), Color(0xFF4F39A9), Color(0xFF2239A1),
  ];

  /// Numerals on number cards: the band's hue, deepened where needed to at least 4.5:1 on [cardFace].
  static const numberInks = <Color>[
    Color(0xFF967103), Color(0xFF967103), Color(0xFFA36A02), Color(0xFFB46102), Color(0xFFCB4F10), //
    Color(0xFFCE4943), Color(0xFFCC4666), Color(0xFFC5477F), Color(0xFFAF4191), Color(0xFF923DA0), //
    Color(0xFF723BA8), Color(0xFF4F39A9), Color(0xFF2239A1),
  ];

  static const shadow = Color(0x55000000);
  static const scrim = Color(0xB3061C16);

  static const errorContainer = Color(0xFFFFB4AB);
  static const onErrorContainer = Color(0xFF690005);
}
