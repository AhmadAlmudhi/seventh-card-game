// Screen gallery: every screen with sample states, for design review and screenshots. Not part
// of the app.
//
//   flutter run -d chrome -t lib/dev/gallery_main.dart
//   …then open #/?screen=game&lang=en (screens: home, join, how, lobby, lobby-guest, lobby-waiting,
//   lobby-8, game, game-waiting, game-choose, game-8, game-8-mine, counter, round-over, paused,
//   results, tutorial, tutorial-bot, tutorial-results, effects, error).
//   `replay` plays a recorded 8-player round through the real playback, with sound (tap once to
//   allow it); add `&stats=1` for frame times.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../l10n/app_localizations.dart';
import '../net/protocol.dart';
import '../screens/home_screen.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/join_screen.dart';
import '../screens/room_screen.dart';
import '../state/prefs.dart';
import '../state/room_controller.dart';
import '../state/tutorial_coach.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/card_counter_sheet.dart';
import '../widgets/last_card_stage.dart';
import '../widgets/ui.dart';
import 'fixtures.dart';
import 'icon_art.dart';
import 'replay.dart';

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
    'effects' => const _EffectsSheet(),
    'icon' => const Material(child: IconArt()),
    'counter' => const _OpensCounter(child: RoomScreen(code: fixtureCode)),
    'replay' => ReplayDriver(
      stats: query['stats'] == '1',
      child: const RoomScreen(code: fixtureCode),
    ),
    _ => const RoomScreen(code: fixtureCode),
  };

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(Prefs(prefs)),
        roomProvider.overrideWith(
          () => screen == 'replay' ? ReplayRoomController() : FixtureRoomController(fixtureState(screen)),
        ),
        tutorialCoachProvider.overrideWith(() => FixtureCoach(fixtureCoach(screen))),
      ],
      child: SeventhCardApp(
        router: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => page)],
        ),
      ),
    ),
  );
}

/// Opens the card counter over the game screen once it's shown.
class _OpensCounter extends StatefulWidget {
  const _OpensCounter({required this.child});

  final Widget child;

  @override
  State<_OpensCounter> createState() => _OpensCounterState();
}

class _OpensCounterState extends State<_OpensCounter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showCardCounter(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Every last-card effect, frozen part-way through, for design review.
class _EffectsSheet extends StatelessWidget {
  const _EffectsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = double.tryParse(Uri.base.queryParameters['t'] ?? '') ?? 0.55;
    final samples = <(String, GameCard, StageEffect, String?)>[
      ('7', const GameCard(id: 'a', kind: CardKind.number, value: 7), StageEffect.plain, null),
      ('bust', const GameCard(id: 'b', kind: CardKind.number, value: 11), StageEffect.bust, l10n.stageBust),
      ('saved', const GameCard(id: 'c', kind: CardKind.number, value: 9), StageEffect.saved, l10n.stageSaved),
      ('seventh', const GameCard(id: 'd', kind: CardKind.number, value: 4), StageEffect.seventh, l10n.seventhCard),
      ('freeze', const GameCard(id: 'e', kind: CardKind.freeze), StageEffect.freeze, null),
      ('flip3', const GameCard(id: 'f', kind: CardKind.flipThree), StageEffect.flipThree, null),
      ('sc', const GameCard(id: 'g', kind: CardKind.secondChance), StageEffect.secondChance, null),
      ('x2', const GameCard(id: 'h', kind: CardKind.x2), StageEffect.modifier, null),
    ];
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.95,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (label, card, effect, stamp) in samples)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LastCardStage(
                        card: card,
                        effect: effect,
                        width: 64,
                        stampLabel: stamp,
                        debugProgress: effect == StageEffect.plain ? 1 : progress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(label, style: AppText.caption.copyWith(color: AppColors.onTableMuted)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
