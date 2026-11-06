import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/how_to_play_screen.dart';
import 'screens/join_screen.dart';
import 'screens/room_screen.dart';
import 'state/settings.dart';
import 'theme/theme.dart';

/// Routes. On the web these use the URL hash (`#/room/K7Q2M`), so links work on GitHub Pages
/// without server rewrites (PRD §7). Hash URLs are Flutter's web default.
GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/join',
      builder: (_, state) => JoinScreen(initialCode: state.uri.queryParameters['code']),
    ),
    GoRoute(path: '/how-to-play', builder: (_, _) => const HowToPlayScreen()),
    GoRoute(
      path: '/room/:code',
      builder: (_, state) => RoomScreen(code: (state.pathParameters['code'] ?? '').toUpperCase()),
    ),
  ],
);

class SeventhCardApp extends ConsumerStatefulWidget {
  const SeventhCardApp({super.key, this.router});

  /// Tests can pass their own router (for example, starting on another route).
  final GoRouter? router;

  @override
  ConsumerState<SeventhCardApp> createState() => _SeventhCardAppState();
}

class _SeventhCardAppState extends ConsumerState<SeventhCardApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
