import 'package:flutter/material.dart';

import 'config.dart';
import 'l10n/app_localizations.dart';
import 'screens/coming_soon_screen.dart';
import 'theme/theme.dart';

class SeventhCardApp extends StatelessWidget {
  const SeventhCardApp({super.key, this.locale = const Locale(AppConfig.locale)});

  /// The language to show. Tests pass this directly; the app uses [AppConfig.locale].
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ComingSoonScreen(),
    );
  }
}
