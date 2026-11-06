import 'package:flutter/painting.dart';

import 'colors.dart';

/// Text styles (PRD §6.1). Cairo covers Arabic and Latin, so both languages share one look.
///
/// Never set `letterSpacing` on text that can be Arabic: it breaks the joined letters.
abstract final class AppText {
  static const fontFamily = 'Cairo';

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.15,
    color: AppColors.onTable,
  );
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.onTable,
  );
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.onTable,
  );
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.onTable,
  );
  static const bodyMuted = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.onTableMuted,
  );
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.onTableMuted,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.onTableMuted,
  );
  static const button = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w800);
  static const score = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.gold,
  );

  /// Latin-only small caps line under the logo. Letter spacing is safe here: it's never Arabic.
  static const latinTagline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    color: AppColors.onTableMuted,
  );

  /// Numerals on cards and big numbers: tight line box so they center exactly.
  static TextStyle numeral(double size, Color color) => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w900,
    fontSize: size,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );
}
