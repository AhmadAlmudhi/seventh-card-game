import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// The app's only theme. Pass it to `theme:` and never set `darkTheme:` (PRD §6.1).
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.onTable,
    onPrimary: AppColors.table,
    secondary: AppColors.onTable,
    onSecondary: AppColors.table,
    error: AppColors.error,
    onError: AppColors.onError,
    surface: AppColors.table,
    onSurface: AppColors.onTable,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.table,
    fontFamily: AppText.fontFamily,
  );
}
