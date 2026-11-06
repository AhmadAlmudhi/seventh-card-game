import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/room_api.dart';
import '../state/nickname_rules.dart';
import '../state/prefs.dart';
import '../state/room_controller.dart';
import '../state/settings.dart';
import '../state/tutorial_coach.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/ui.dart';

/// Home (PRD §4.1): language and sound, the logo, a nickname, and the ways in: create, join, the
/// tutorial game, and how to play.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final _nickname = TextEditingController(text: ref.read(nicknameProvider));
  bool _showNicknameError = false;
  bool _creating = false;
  bool _startingTutorial = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  /// Saves the nickname and returns true if it's valid; otherwise shows why.
  bool _confirmNickname() {
    final valid = NicknameRules.isValid(_nickname.text);
    setState(() => _showNicknameError = !valid);
    if (valid) ref.read(nicknameProvider.notifier).set(NicknameRules.clean(_nickname.text));
    return valid;
  }

  Future<void> _create() async {
    if (!_confirmNickname() || _creating) return;
    setState(() => _creating = true);
    try {
      final code = await ref.read(roomApiProvider).createRoom();
      if (mounted) context.go('/room/$code');
    } on RoomApiException catch (e) {
      if (mounted) {
        showToast(context, errorMessage(AppLocalizations.of(context), e.code), icon: Icons.cloud_off_rounded);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _join() {
    if (_confirmNickname()) context.push('/join');
  }

  /// A game against the bot (PRD §4.9). It needs no nickname: the app always calls this player
  /// "You", so an empty field just uses that word.
  Future<void> _tutorial() async {
    if (_startingTutorial || _creating) return;
    final l10n = AppLocalizations.of(context);
    final typed = _nickname.text;
    final valid = NicknameRules.isValid(typed);
    if (valid) ref.read(nicknameProvider.notifier).set(NicknameRules.clean(typed));
    setState(() {
      _showNicknameError = false;
      _startingTutorial = true;
    });
    try {
      final code = await ref.read(roomApiProvider).createRoom(tutorial: true);
      if (!mounted) return;
      ref.read(tutorialCoachProvider.notifier).reset();
      ref.read(roomProvider.notifier).enter(code, valid ? NicknameRules.clean(typed) : l10n.you);
      context.go('/room/$code');
    } on RoomApiException catch (e) {
      if (mounted) showToast(context, errorMessage(l10n, e.code), icon: Icons.cloud_off_rounded);
    } finally {
      if (mounted) setState(() => _startingTutorial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(prefsProvider).session;
    final inRoom = ref.watch(roomProvider.select((s) => s.code));
    final inTutorial = ref.watch(roomProvider.select((s) => s.view?.tutorial));
    final resumeCode = inRoom ?? session?.roomCode;
    final resumeTutorial = inTutorial ?? (session?.roomCode == resumeCode && (session?.tutorial ?? false));

    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: ContentWidth(
            child: FillScroll(
              children: [
                const SizedBox(height: AppSpacing.sm),
                const Row(children: [LanguageToggle(), Spacer(), SoundToggleButton()]),
                const Spacer(flex: 3),
                const SizedBox(height: AppSpacing.lg),
                const Logo(),
                const SizedBox(height: AppSpacing.lg),
                const Spacer(flex: 3),
                if (resumeCode != null) ...[
                  AppButton(
                    label: resumeTutorial ? l10n.returnToTutorial : l10n.returnToRoom(resumeCode),
                    icon: Icons.replay_rounded,
                    kind: AppButtonKind.secondary,
                    onPressed: () => context.go('/room/$resumeCode'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs, bottom: 6),
                    child: Text(l10n.nicknameLabel, style: AppText.label),
                  ),
                ),
                AppTextField(
                  controller: _nickname,
                  hint: l10n.nicknameHint,
                  icon: Icons.person_rounded,
                  maxLength: 24,
                  errorText: _showNicknameError ? l10n.nicknameInvalid : null,
                  onChanged: (_) {
                    if (_showNicknameError) setState(() => _showNicknameError = !NicknameRules.isValid(_nickname.text));
                  },
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: AppSpacing.md + 2),
                AppButton(label: l10n.createRoom, icon: Icons.add_rounded, loading: _creating, onPressed: _create),
                const SizedBox(height: 12),
                AppButton(
                  label: l10n.joinRoom,
                  icon: Icons.login_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: _join,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: l10n.tutorialButton,
                  icon: Icons.school_rounded,
                  kind: AppButtonKind.secondary,
                  loading: _startingTutorial,
                  onPressed: _tutorial,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: l10n.howToPlay,
                  icon: Icons.help_outline_rounded,
                  kind: AppButtonKind.quiet,
                  minHeight: AppSpacing.minTouch,
                  onPressed: () => context.push('/how-to-play'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The top bar used by inner screens: a back button and a title.
class SimpleTopBar extends StatelessWidget {
  const SimpleTopBar({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final back = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          RoundIconButton(
            icon: back,
            tooltip: l10n.back,
            onPressed: onBack ?? () => context.canPop() ? context.pop() : context.go('/'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(title, style: AppText.title.copyWith(fontSize: 22), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Space reserved under the top bar color.
const kTopBarColor = AppColors.table;
