import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/protocol.dart';
import '../state/nickname_rules.dart';
import '../state/room_controller.dart';
import '../state/settings.dart';
import '../state/table_director.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/ui.dart';
import 'game_view.dart';
import 'lobby_view.dart';
import 'results_view.dart';

/// Everything at `#/room/CODE`: asks for a nickname if needed, joins, then shows the lobby, the
/// game or the results, following the server's phase (PRD §4.4–4.7).
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterIfReady());
  }

  void _enterIfReady() {
    final nickname = ref.read(nicknameProvider);
    if (!mounted || !RoomCodeRules.isValid(widget.code) || !NicknameRules.isValid(nickname)) return;
    ref.read(roomProvider.notifier).enter(widget.code, NicknameRules.clean(nickname));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen(roomProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showToast(context, errorMessage(l10n, notice.code));
      ref.read(roomProvider.notifier).clearNotice();
    });

    final room = ref.watch(roomProvider);
    final nickname = ref.watch(nicknameProvider);
    // The phase on screen: during playback it trails the server, so the last round finishes playing
    // before the results appear (PRD §9.3).
    final shownPhase = ref.watch(tableViewProvider.select((v) => v?.phase));
    final Widget body;
    if (!RoomCodeRules.isValid(widget.code)) {
      body = const _RoomMessage(code: 'ROOM_NOT_FOUND', key: ValueKey('bad-code'));
    } else if (room.code != widget.code && !NicknameRules.isValid(nickname)) {
      body = _NicknamePrompt(code: widget.code, onJoin: _enterIfReady, key: const ValueKey('nickname'));
    } else if (room.code == widget.code && room.error != null) {
      body = _RoomMessage(code: room.error!, key: ValueKey('error-${room.error}'));
    } else if (room.code != widget.code || room.view == null) {
      body = _Connecting(key: const ValueKey('connecting'), label: l10n.connecting);
    } else {
      final view = room.view!;
      final me = room.me;
      body = switch (shownPhase ?? view.phase) {
        Phase.abandoned => const _RoomMessage(code: 'GAME_ABANDONED', key: ValueKey('abandoned')),
        Phase.lobby => const LobbyView(key: ValueKey('lobby')),
        Phase.results when me?.returned ?? true => const LobbyView(key: ValueKey('lobby')),
        Phase.results => const ResultsView(key: ValueKey('results')),
        _ => const GameView(key: ValueKey('game')),
      };
    }

    return Scaffold(
      body: FeltBackground(
        glowCenter: const Alignment(0, -0.05),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              child: body,
            ),
            if (room.code == widget.code && room.status == LinkStatus.reconnecting)
              const Positioned(top: 0, left: 0, right: 0, child: _ReconnectingBanner()),
          ],
        ),
      ),
    );
  }
}

/// A slim banner over the game while the app reconnects (PRD §4.7).
class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.onGold,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 16)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.reconnecting, style: AppText.label.copyWith(color: AppColors.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 36, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.gold)),
          const SizedBox(height: AppSpacing.lg),
          Text(label, style: AppText.body),
        ],
      ),
    ),
  );
}

/// A deep link opened without a saved nickname: ask for one, then join (PRD §4.3).
class _NicknamePrompt extends ConsumerStatefulWidget {
  const _NicknamePrompt({super.key, required this.code, required this.onJoin});

  final String code;
  final VoidCallback onJoin;

  @override
  ConsumerState<_NicknamePrompt> createState() => _NicknamePromptState();
}

class _NicknamePromptState extends ConsumerState<_NicknamePrompt> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _join() {
    if (!NicknameRules.isValid(_controller.text)) {
      setState(() => _showError = true);
      return;
    }
    ref.read(nicknameProvider.notifier).set(NicknameRules.clean(_controller.text));
    widget.onJoin();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ContentWidth(
        child: FillScroll(
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Row(children: [LanguageToggle(), Spacer(), SoundToggleButton()]),
            const Spacer(),
            const Logo(scale: 0.8),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.nicknamePromptTitle(widget.code), style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _controller,
              hint: l10n.nicknameHint,
              icon: Icons.person_rounded,
              autofocus: true,
              maxLength: 24,
              errorText: _showError ? l10n.nicknameInvalid : null,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: l10n.joinButton, icon: Icons.login_rounded, onPressed: _join),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// A final message for this visit to the room, with a way home (PRD §4.3, §4.7).
class _RoomMessage extends ConsumerWidget {
  const _RoomMessage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canRetry = code == 'CONNECTION_LOST' || code == 'ROOM_BUSY';
    final icon = switch (code) {
      'REMOVED' || 'SEAT_LOST' => Icons.person_off_rounded,
      'CONNECTION_LOST' || 'NETWORK' => Icons.wifi_off_rounded,
      'GAME_ABANDONED' => Icons.hourglass_disabled_rounded,
      _ => Icons.meeting_room_rounded,
    };
    void home() {
      ref.read(roomProvider.notifier).reset();
      context.go('/');
    }

    return SafeArea(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: Icon(icon, color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(errorMessage(l10n, code), style: AppText.heading.copyWith(height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              if (canRetry) ...[
                AppButton(
                  label: l10n.tryAgain,
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    final roomCode = ref.read(roomProvider).code;
                    ref.read(roomProvider.notifier).reset();
                    if (roomCode != null) {
                      ref.read(roomProvider.notifier).enter(roomCode, NicknameRules.clean(ref.read(nicknameProvider)));
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: l10n.goHome,
                icon: Icons.home_rounded,
                kind: canRetry ? AppButtonKind.secondary : AppButtonKind.primary,
                onPressed: home,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
