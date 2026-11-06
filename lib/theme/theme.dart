import 'package:flutter/material.dart';

import 'colors.dart';
import 'motion.dart';
import 'typography.dart';

/// The app's only theme. Pass it to `theme:` and never set `darkTheme:` (PRD §6.1).
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.gold,
    onPrimary: AppColors.onGold,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onTable,
    error: AppColors.errorContainer,
    onError: AppColors.onErrorContainer,
    surface: AppColors.panel,
    onSurface: AppColors.onTable,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.table,
    fontFamily: AppText.fontFamily,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.gold,
      selectionColor: Color(0x66E9B949),
      selectionHandleColor: AppColors.gold,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final platform in TargetPlatform.values) platform: const _FadeThroughTransitions()},
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.all(Radius.circular(10))),
      textStyle: AppText.label,
    ),
  );
}

/// One consistent screen transition everywhere: a short fade with a slight rise (PRD §6.0).
class _FadeThroughTransitions extends PageTransitionsBuilder {
  const _FadeThroughTransitions();

  @override
  Duration get transitionDuration => AppMotion.screen;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
