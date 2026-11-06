// Screen gallery: every screen with sample states, for design review and screenshots. Not part
// of the app.
//
//   flutter run -d chrome -t lib/dev/gallery_main.dart
//   …then open #/?screen=game&lang=en (screens: home, join, how, lobby, lobby-guest,
//   lobby-waiting, game, game-waiting, game-choose, round-over, paused, results, error).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../screens/home_screen.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/join_screen.dart';
import '../screens/room_screen.dart';
import '../state/prefs.dart';
import '../state/room_controller.dart';
import 'fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final screen = query['screen'] ?? 'home';
  final lang = query['lang'] ?? 'ar';

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', lang);
  await prefs.setString('nickname', 'عبدالله');

  final Widget page = switch (screen) {
    'home' => const HomeScreen(),
    'join' => const JoinScreen(initialCode: 'K7Q'),
    'how' => const HowToPlayScreen(),
    _ => const RoomScreen(code: fixtureCode),
  };

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(Prefs(prefs)),
        roomProvider.overrideWith(() => FixtureRoomController(fixtureState(screen))),
      ],
      child: SeventhCardApp(
        router: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => page)],
        ),
      ),
    ),
  );
}
