import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/messages.dart';
import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/ui.dart';

const _minTarget = 100;
const _maxTarget = 1000;
const _targetStep = 50;
const _defaultTarget = {GameMode.normal: 200, GameMode.hard: 400};

/// The lobby (PRD §4.4), also shown after a game while players come back (PRD §4.6).
class LobbyView extends ConsumerWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider);
    final view = room.view!;
    final code = room.code!;
    final isHost = room.isHost;
    final waitingFor = view.phase == Phase.results
        ? view.players
              .where((p) => !p.returned && p.status != PlayerStatus.left)
              .map((p) => displayName(l10n, p))
              .toList()
        : const <String>[];
    final canStart = isHost && view.phase == Phase.lobby && view.players.length >= 2;
    final controller = ref.read(roomProvider.notifier);

    Future<void> leave() async {
      final ok = await confirmDialog(
        context,
        title: l10n.leaveConfirmTitle,
        confirmLabel: l10n.leave,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (!ok) return;
      await controller.quit();
      if (context.mounted) context.go('/');
    }

    return SafeArea(
      child: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: Icons.logout_rounded, tooltip: l10n.leaveRoom, onPressed: leave),
                  const Spacer(),
                  const SoundToggleButton(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
                children: [
                  _RoomCodeCard(code: code),
                  const SizedBox(height: AppSpacing.md),
                  if (waitingFor.isNotEmpty) ...[
                    _Banner(icon: Icons.hourglass_top_rounded, text: l10n.waitingFor(joinNames(l10n, waitingFor))),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _PlayersPanel(view: view, myId: room.playerId, isHost: isHost),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsPanel(view: view, editable: isHost && view.phase == Phase.lobby),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
              child: Column(
                children: [
                  if (isHost && view.players.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(l10n.needTwoPlayers, style: AppText.bodyMuted, textAlign: TextAlign.center),
                    ),
                  if (isHost)
                    AppButton(
                      label: l10n.startGame,
                      icon: Icons.play_arrow_rounded,
                      onPressed: canStart ? controller.start : null,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          ),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Flexible(child: Text(l10n.waitingForHost, style: AppText.body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Panel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(l10n.roomCodeLabel, style: AppText.label),
          const SizedBox(height: AppSpacing.xs),
          // Room codes are always left-to-right Latin capitals (PRD §6.6). Latin, so letter spacing is safe.
          Text(
            code,
            textDirection: TextDirection.ltr,
            style: AppText.numeral(44, AppColors.gold).copyWith(letterSpacing: 8, height: 1.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.copyCode,
                  icon: Icons.copy_rounded,
                  kind: AppButtonKind.secondary,
                  minHeight: 48,
                  dense: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) showToast(context, l10n.codeCopied, icon: Icons.check_circle_rounded);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: AppButton(
                  label: l10n.shareLink,
                  icon: Icons.ios_share_rounded,
                  kind: AppButtonKind.secondary,
                  minHeight: 48,
                  dense: true,
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(text: l10n.shareMessage(AppConfig.roomLink(code)))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 15))),
      ],
    ),
  );
}

class _PlayersPanel extends ConsumerWidget {
  const _PlayersPanel({required this.view, required this.myId, required this.isHost});

  final RoomView view;
  final String? myId;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final players = view.players.where((p) => p.status != PlayerStatus.left).toList();
    final canRemove = isHost && (view.phase == Phase.lobby || view.phase == Phase.results);

    Future<void> remove(PlayerView player) async {
      final ok = await confirmDialog(
        context,
        title: l10n.removeConfirmTitle(isolate(player.nickname)),
        body: l10n.removeConfirmBody,
        confirmLabel: l10n.remove,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (ok) ref.read(roomProvider.notifier).remove(player.id);
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.playersTitle(players.length), style: AppText.heading),
          const SizedBox(height: AppSpacing.sm),
          for (final player in players)
            _JoinIn(
              key: ValueKey(player.id),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Opacity(
                      opacity: player.connected ? 1 : 0.5,
                      child: PlayerAvatar(nickname: player.nickname, size: 34, highlight: player.id == myId),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.nickname,
                              style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (player.id == view.hostId) ...[
                            Tooltip(
                              message: l10n.hostTag,
                              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          if (player.id == myId) StatusChip(label: l10n.youTag, color: AppColors.gold),
                          if (!player.connected) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Tooltip(
                              message: l10n.statusReconnecting,
                              child: Semantics(
                                label: l10n.statusReconnecting,
                                child: const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.onTableMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canRemove && player.id != myId)
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        tooltip: l10n.removePlayer,
                        onPressed: () => remove(player),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends ConsumerWidget {
  const _SettingsPanel({required this.view, required this.editable});

  final RoomView view;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(roomProvider.notifier);

    void setMode(GameMode mode) {
      if (mode != view.mode) controller.changeSettings(mode, _defaultTarget[mode]!);
    }

    void setTarget(int target) => controller.changeSettings(view.mode, target.clamp(_minTarget, _maxTarget));

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsTitle, style: AppText.heading),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.modeLabel, style: AppText.label),
          const SizedBox(height: AppSpacing.sm),
          _Segmented(
            options: [(GameMode.normal, l10n.modeNormal), (GameMode.hard, l10n.modeHard)],
            selected: view.mode,
            onSelected: editable ? setMode : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.targetLabel, style: AppText.label),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (editable)
                RoundIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.decreaseTarget,
                  onPressed: view.targetScore > _minTarget ? () => setTarget(view.targetScore - _targetStep) : null,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    '${view.targetScore}',
                    key: ValueKey(view.targetScore),
                    textAlign: TextAlign.center,
                    style: AppText.numeral(32, AppColors.onTable),
                  ),
                ),
              ),
              if (editable)
                RoundIconButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.increaseTarget,
                  onPressed: view.targetScore < _maxTarget ? () => setTarget(view.targetScore + _targetStep) : null,
                ),
            ],
          ),
          if (view.mode == GameMode.hard) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: StatusChip(
                label: l10n.forcedLineNote(view.forcedLine),
                icon: Icons.whatshot_rounded,
                color: AppColors.flipThree,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, this.onSelected});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.table,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.panelBorder),
    ),
    child: Row(
      children: [
        for (final (value, label) in options)
          Expanded(
            child: Semantics(
              button: onSelected != null,
              selected: value == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelected == null ? null : () => onSelected!(value),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? AppColors.gold : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    label,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w800,
                      color: value == selected ? AppColors.onGold : AppColors.onTableMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A player's row slides and fades in when they join (PRD §6.3). Rows already there keep still.
class _JoinIn extends StatefulWidget {
  const _JoinIn({super.key, required this.child});

  final Widget child;

  @override
  State<_JoinIn> createState() => _JoinInState();
}

class _JoinInState extends State<_JoinIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.medium);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value > 0 || _controller.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: SlideTransition(
      position: _controller.drive(
        Tween(begin: const Offset(0, 0.3), end: Offset.zero).chain(CurveTween(curve: AppMotion.enter)),
      ),
      child: widget.child,
    ),
  );
}
