import 'package:flutter/painting.dart';

import 'colors.dart';

/// Text styles (PRD §6.1). Cairo covers Arabic and Latin, so both languages
/// share one look.
///
/// Never set `letterSpacing` on these: it breaks the joined letters of Arabic.
abstract final class AppText {
  static const fontFamily = 'Cairo';

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.onTable,
  );

  static const subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.onTableMuted,
  );
}
