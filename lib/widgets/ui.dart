import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/settings.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'playing_card.dart';

// -----------------------------------------------------------------------------
// Layout
// -----------------------------------------------------------------------------

/// The felt: a deep green with a soft glow, behind every screen.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child, this.glowCenter = const Alignment(0, -0.3)});

  final Widget child;
  final Alignment glowCenter;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(center: glowCenter, radius: 1.15, colors: const [AppColors.tableLight, AppColors.table]),
    ),
    child: child,
  );
}

/// Keeps phone-style layouts a comfortable width on tablets and desktops.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = AppSpacing.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A scrollable column that still fills the screen, so Spacers work and large text never overflows.
class FillScroll extends StatelessWidget {
  const FillScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: padding,
            child: Column(children: children),
          ),
        ),
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md), this.highlight});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Draws a glowing border in this color (for example, the player whose turn it is).
  final Color? highlight;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.medium,
    curve: AppMotion.standard,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.panel.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: highlight ?? AppColors.panelBorder, width: highlight != null ? 2 : 1),
      boxShadow: highlight != null ? [BoxShadow(color: highlight!.withValues(alpha: 0.35), blurRadius: 18)] : const [],
    ),
    child: child,
  );
}

// -----------------------------------------------------------------------------
// Buttons
// -----------------------------------------------------------------------------

enum AppButtonKind { primary, secondary, quiet, danger }

/// Every button in the app: pressed, disabled and loading states included (PRD §6.0).
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.minHeight = 58,
    this.expand = true,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final double minHeight;

  /// Fill the available width (the default). Turn off for buttons that sit in an unbounded row.
  final bool expand;

  /// Smaller text and padding, for two buttons side by side.
  final bool dense;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final (Color? fill, Color fg, BoxBorder? border) = switch (widget.kind) {
      AppButtonKind.primary => (AppColors.gold, AppColors.onGold, null),
      AppButtonKind.secondary => (
        AppColors.secondary,
        AppColors.onTable,
        Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      AppButtonKind.quiet => (null, AppColors.onTableMuted, null),
      AppButtonKind.danger => (
        AppColors.danger.withValues(alpha: 0.14),
        AppColors.danger,
        Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
    };
    final radius = BorderRadius.circular(AppRadii.button);
    final glow = widget.kind == AppButtonKind.primary && enabled
        ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]
        : const <BoxShadow>[];

    return AnimatedScale(
      scale: _pressed ? AppMotion.pressedScale : 1,
      duration: AppMotion.press,
      curve: AppMotion.standard,
      child: AnimatedOpacity(
        opacity: enabled || widget.loading ? 1 : 0.42,
        duration: AppMotion.fast,
        // The glow sits outside the Material: shadows drawn on the ink layer get clipped square.
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: glow),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(color: fill, borderRadius: radius, border: border),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(widget.minHeight, AppSpacing.minTouch),
                    minWidth: widget.expand ? double.infinity : 0,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.dense ? 12 : AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.loading)
                          SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                        else if (widget.icon != null)
                          Icon(widget.icon, color: fg, size: widget.dense ? 19 : 22),
                        if (widget.loading || widget.icon != null) const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: AppText.button.copyWith(color: fg, fontSize: widget.dense ? 15 : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button: 44 px circle inside a 48 px touch target, always labelled (PRD §6.5).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.badge});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: AppSpacing.minTouch,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: AppColors.onTable, size: 22),
                    if (badge != null) PositionedDirectional(top: -6, end: -8, child: badge!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Small pieces
// -----------------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.color, this.icon, this.filled = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onTableMuted;
    final fg = filled ? AppColors.table : c;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 10, 2),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: AppSpacing.xs)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circle with the player's first letter.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.nickname, this.size = 28, this.highlight = false});

  final String nickname;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: highlight ? AppColors.gold : AppColors.secondary),
    child: Text(
      nickname.characters.isEmpty ? '?' : nickname.characters.first.toUpperCase(),
      style: AppText.label.copyWith(
        fontSize: size * 0.46,
        fontWeight: FontWeight.w800,
        color: highlight ? AppColors.onGold : AppColors.onTable,
        height: 1,
      ),
    ),
  );
}

/// The nickname and room-code fields.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.icon,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.style,
    this.maxLength,
    this.inputFormatters,
    this.keyboardType,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextStyle? style;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textDirection: textDirection,
      textAlign: textAlign,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: style ?? AppText.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.panel,
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: AppColors.onTableMuted.withValues(alpha: 0.7)),
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.onTableMuted),
        counterText: '',
        errorText: errorText,
        errorStyle: AppText.caption.copyWith(color: AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
        enabledBorder: border(AppColors.panelBorder),
        focusedBorder: border(AppColors.gold, 2),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 2),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Toggles
// -----------------------------------------------------------------------------

/// `العربية | English`: each name in its own language, whichever is active (PRD §6.6).
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(languageProvider).languageCode;
    Widget segment(String code, String label, TextDirection direction) {
      final selected = current == code;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(languageProvider.notifier).set(Locale(code)),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? AppColors.gold : null, borderRadius: BorderRadius.circular(20)),
            child: Text(
              label,
              textDirection: direction,
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.onGold : AppColors.onTableMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('ar', l10n.languageArabic, TextDirection.rtl),
          segment('en', l10n.languageEnglish, TextDirection.ltr),
        ],
      ),
    );
  }
}

class SoundToggleButton extends ConsumerWidget {
  const SoundToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(soundProvider);
    return RoundIconButton(
      icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      tooltip: on ? l10n.soundOn : l10n.soundOff,
      onPressed: () => ref.read(soundProvider.notifier).toggle(),
    );
  }
}

// -----------------------------------------------------------------------------
// Logo
// -----------------------------------------------------------------------------

class Logo extends StatelessWidget {
  const Logo({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: l10n.appTitle,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130 * scale,
              height: 116 * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(-22 * scale, 4 * scale),
                    child: Transform.rotate(angle: -0.22, child: PlayingCard.back(width: 64 * scale, emblem: false)),
                  ),
                  Transform.translate(
                    offset: Offset(14 * scale, 0),
                    child: Transform.rotate(
                      angle: 0.12,
                      child: Container(
                        width: 70 * scale,
                        height: 98 * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardFace,
                          borderRadius: BorderRadius.circular(11 * scale),
                          border: Border.all(color: AppColors.gold, width: 2.5 * scale),
                          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
                        ),
                        child: Text('7', style: AppText.numeral(60 * scale, const Color(0xFFB8860B))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14 * scale),
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: AppText.display.copyWith(fontSize: 40 * scale),
            ),
            SizedBox(height: 2 * scale),
            Text(
              l10n.logoTagline,
              textDirection: TextDirection.ltr,
              style: AppText.latinTagline.copyWith(fontSize: 12 * scale),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dialogs and notices
// -----------------------------------------------------------------------------

/// A styled confirmation dialog. Resolves true if the player confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: AppColors.scrim,
    transitionDuration: AppMotion.medium,
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(AppRadii.sheet),
                border: Border.all(color: AppColors.panelBorder),
                boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 30, offset: Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppText.title.copyWith(fontSize: 22)),
                  if (body != null) ...[const SizedBox(height: AppSpacing.sm), Text(body, style: AppText.bodyMuted)],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: cancelLabel,
                          kind: AppButtonKind.secondary,
                          minHeight: 52,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: confirmLabel,
                          kind: destructive ? AppButtonKind.danger : AppButtonKind.primary,
                          minHeight: 52,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
      );
    },
  );
  return result ?? false;
}

/// A short message at the bottom of the screen.
void showToast(BuildContext context, String message, {IconData icon = Icons.info_outline_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel,
        elevation: 0,
        duration: const Duration(milliseconds: 2600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppText.body.copyWith(fontSize: 15))),
          ],
        ),
      ),
    );
}

// -----------------------------------------------------------------------------
// Timer ring
// -----------------------------------------------------------------------------

/// Counts down to a server deadline (PRD §6.3). The server enforces the timer; this only shows it.
class TimerRing extends StatefulWidget {
  const TimerRing({
    super.key,
    required this.deadline,
    required this.totalMs,
    required this.clockOffsetMs,
    this.size = 32,
  });

  /// Server time (ms) when the decision times out.
  final int deadline;
  final int totalMs;
  final int clockOffsetMs;
  final double size;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _tick;
  int _secondsLeft = 0;

  int get _remainingMs => widget.deadline - (DateTime.now().millisecondsSinceEpoch + widget.clockOffsetMs);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TimerRing old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline || old.clockOffsetMs != widget.clockOffsetMs) _restart();
  }

  void _restart() {
    final remaining = _remainingMs.clamp(0, widget.totalMs);
    _controller.value = remaining / widget.totalMs;
    if (remaining > 0) {
      _controller.animateTo(
        0,
        duration: Duration(milliseconds: remaining),
        curve: Curves.linear,
      );
    }
    _secondsLeft = (remaining / 1000).ceil();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final seconds = (_remainingMs.clamp(0, widget.totalMs) / 1000).ceil();
      if (seconds != _secondsLeft && mounted) setState(() => _secondsLeft = seconds);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _secondsLeft <= 5;
    final color = urgent ? AppColors.danger : AppColors.gold;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) =>
                  CustomPaint(size: Size.square(widget.size), painter: _RingPainter(_controller.value, color)),
            ),
            Text('$_secondsLeft', style: AppText.numeral(widget.size * 0.38, color)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = AppColors.panelBorder);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
