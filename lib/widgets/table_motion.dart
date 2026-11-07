import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/sounds.dart';
import '../state/table_director.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';

/// Where things are on the game screen, so cards can fly between them (PRD §6.3).
///
/// The keys belong to the game screen and live as long as it does: new keys would rebuild the
/// widgets they're on from scratch, losing their animations.
class TableGeometry extends InheritedWidget {
  const TableGeometry({super.key, required this.stageKey, required this.counterKey, required super.child});

  /// The card in the middle of the table: where revealed cards come from.
  final GlobalKey stageKey;

  /// The card counter button: where discarded cards go.
  final GlobalKey counterKey;

  static TableGeometry? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<TableGeometry>();

  @override
  bool updateShouldNotify(TableGeometry oldWidget) =>
      stageKey != oldWidget.stageKey || counterKey != oldWidget.counterKey;
}

/// The global rectangle of a widget, or null if it isn't laid out.
Rect? globalRect(BuildContext? context) {
  final box = context?.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// A card in a row. When playback brings it in, it flies from the middle of the table to its place
/// along a slight arc and lands with a small bounce. When it leaves (a used Second Chance, or the
/// table clearing), it lifts and fades. Only its transform and opacity change (PRD §6.0).
///
/// A card that's on the table is always visible in the end, whatever happened to its animation:
/// one marked as leaving that's still there afterwards fades back in, and one waiting to fly in
/// shows anyway if its flight never starts.
class MotionCard extends ConsumerStatefulWidget {
  const MotionCard({super.key, required this.cardId, required this.child});

  final String cardId;
  final Widget child;

  @override
  ConsumerState<MotionCard> createState() => _MotionCardState();
}

enum _Motion { resting, waiting, arriving, leaving }

class _MotionCardState extends ConsumerState<MotionCard> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  _Motion _motion = _Motion.resting;
  Offset _from = Offset.zero;
  double _fromScale = 1;

  /// Shows the card if its flight hasn't started by then (it normally starts within ~0.3 s).
  Timer? _waitLimit;

  @override
  void initState() {
    super.initState();
    final table = ref.read(tableDirectorProvider);
    if (table.arriving.contains(widget.cardId)) {
      _motion = _Motion.waiting;
      _waitLimit = Timer(const Duration(milliseconds: 1500), _settle);
      // A freshly revealed card waits for its flip in the middle of the table to finish.
      final delay = table.cue?.type == 'cardDealt'
          ? AppMotion.reveal - const Duration(milliseconds: 40)
          : Duration.zero;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (delay == Duration.zero) {
          _arrive();
        } else {
          Future<void>.delayed(delay, () => _arrive());
        }
      });
    }
  }

  AnimationController _controllerFor(Duration duration) {
    final controller = _controller ??= AnimationController(vsync: this);
    controller.duration = duration;
    return controller;
  }

  void _arrive() {
    if (!mounted || _motion != _Motion.waiting) return;
    _waitLimit?.cancel();
    var from = Offset.zero;
    var fromScale = 1.0;
    try {
      final stage = globalRect(TableGeometry.maybeOf(context)?.stageKey.currentContext);
      final box = context.findRenderObject();
      if (!MediaQuery.disableAnimationsOf(context) &&
          stage != null &&
          box is RenderBox &&
          box.hasSize &&
          box.attached) {
        final mine = Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        );
        from = box.globalToLocal(stage.center) - box.size.center(Offset.zero);
        fromScale = mine.width == 0 ? 1 : (stage.width / mine.width).clamp(0.5, 6.0);
      }
    } catch (_) {
      // Measuring failed: the card fades in where it is instead of flying.
    }
    if (!from.isFinite || !fromScale.isFinite) {
      from = Offset.zero;
      fromScale = 1;
    }
    final flies = from != Offset.zero || fromScale != 1;
    _from = from;
    _fromScale = fromScale;
    _controllerFor(flies ? AppMotion.flight : AppMotion.fast).forward(from: 0);
    setState(() => _motion = _Motion.arriving);
    if (flies) {
      try {
        ref.read(gameFeedbackProvider).play(Sfx.deal);
      } catch (_) {
        // Sound must never get in the way of the card.
      }
    }
  }

  void _leave() {
    if (_motion == _Motion.leaving) return;
    _waitLimit?.cancel();
    final reduced = MediaQuery.disableAnimationsOf(context);
    _controllerFor(reduced ? AppMotion.fast : AppMotion.secondChance).forward(from: 0);
    setState(() => _motion = _Motion.leaving);
  }

  /// Shows the card, plainly. Used when it should have arrived or should have gone, but it's still
  /// here: a card on the table must never stay invisible.
  void _settle() {
    if (!mounted || _motion == _Motion.resting) return;
    if (_motion == _Motion.arriving && (_controller?.isCompleted ?? true)) return;
    _waitLimit?.cancel();
    _controller?.stop();
    setState(() => _motion = _Motion.resting);
  }

  @override
  void didUpdateWidget(MotionCard old) {
    super.didUpdateWidget(old);
    // A different card in this place starts plain.
    if (old.cardId != widget.cardId) _settle();
  }

  @override
  void dispose() {
    _waitLimit?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tableDirectorProvider.select((s) => s.leaving.contains(widget.cardId)), (_, leaving) {
      if (leaving) {
        _leave();
      } else if (_motion == _Motion.leaving) {
        // Normally the card is gone by the next frame. If it's still here then, it's still on the
        // table (the same card came straight back), so it shows again.
        WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
      }
    });
    final controller = _controller;
    switch (_motion) {
      case _Motion.resting:
        return widget.child;
      case _Motion.waiting:
        return Opacity(opacity: 0, child: widget.child);
      case _Motion.arriving:
        if (_fromScale == 1 && _from == Offset.zero) return FadeTransition(opacity: controller!, child: widget.child);
        return AnimatedBuilder(
          animation: controller!,
          // The card is drawn once; only its transform changes as it flies.
          child: RepaintBoundary(child: widget.child),
          builder: (context, child) {
            final t = AppMotion.enter.transform(controller.value);
            final landing = Curves.easeOutBack.transform(controller.value);
            final arc = math.sin(math.pi * t) * -28;
            final scale = _fromScale + (1 - _fromScale) * landing;
            final matrix = Matrix4.identity()
              ..translateByDouble(_from.dx * (1 - t), _from.dy * (1 - t) + arc, 0, 1)
              ..rotateZ((1 - t) * 0.18)
              ..scaleByDouble(scale, scale, 1, 1);
            return Transform(alignment: Alignment.center, transform: matrix, child: child);
          },
        );
      case _Motion.leaving:
        // It swells a little (a glow for a used Second Chance), then lifts away and fades.
        final fade = controller!.drive(
          Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: const Interval(0.35, 1, curve: Curves.easeIn))),
        );
        return FadeTransition(
          opacity: fade,
          child: AnimatedBuilder(
            animation: controller,
            child: RepaintBoundary(child: widget.child),
            builder: (context, child) {
              final t = controller.value;
              final lift = Curves.easeOutBack.transform(math.min(1, t * 2.2));
              final away = 1 - fade.value;
              final scale = 1 + 0.14 * lift - 0.3 * away;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(0, -18 * away, 0, 1)
                  ..scaleByDouble(scale, scale, 1, 1),
                child: child,
              );
            },
          ),
        );
    }
  }
}

/// Plays a one-off effect when the table shows a matching event (PRD §6.3). [builder] gets the
/// effect's progress `t` (0 → 1) and the event; at rest `t` is 1, so it draws the finished state.
/// Only the wrapper [builder] returns repaints each frame; [child] is built once.
class CueEffect extends ConsumerStatefulWidget {
  const CueEffect({super.key, required this.matches, required this.duration, required this.builder, this.child});

  final bool Function(TableCue cue) matches;
  final Duration duration;
  final Widget Function(BuildContext context, double t, TableCue? cue, Widget? child) builder;
  final Widget? child;

  @override
  ConsumerState<CueEffect> createState() => _CueEffectState();
}

class _CueEffectState extends ConsumerState<CueEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration, value: 1);
  TableCue? _cue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tableDirectorProvider.select((s) => s.cue), (_, cue) {
      if (cue == null || !widget.matches(cue)) return;
      _cue = cue;
      _controller.duration = MediaQuery.disableAnimationsOf(context) ? AppMotion.fast : widget.duration;
      _controller.forward(from: 0);
    });
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _controller.value, _cue, child),
    );
  }
}

/// Confetti that bursts and falls once, for the Seventh Card and a win (PRD §6.3). A fixed number
/// of pieces painted in one layer; the controller stops when it lands. Reduce motion skips it.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70, this.seed = 7, this.duration = const Duration(milliseconds: 1800)});

  final int pieces;
  final int seed;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final List<_Piece> _pieces = _makePieces(widget.pieces, widget.seed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isAnimating && _controller.value == 0 && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(painter: _ConfettiPainter(_controller, _pieces), size: Size.infinite),
    ),
  );

  static List<_Piece> _makePieces(int count, int seed) {
    final random = math.Random(seed);
    const colors = [AppColors.gold, AppColors.onTable, AppColors.success, AppColors.info, AppColors.drawThree];
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          x: random.nextDouble(),
          vx: (random.nextDouble() - 0.5) * 0.5,
          vy: 0.35 + random.nextDouble() * 0.55,
          spin: (random.nextDouble() - 0.5) * 14,
          size: 5 + random.nextDouble() * 6,
          color: colors[i % colors.length],
          delay: random.nextDouble() * 0.18,
          round: random.nextBool(),
        ),
    ];
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
    required this.delay,
    required this.round,
  });

  final double x;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
  final double delay;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.animation, this.pieces) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // A burst upward, then gravity, with a little sideways drift.
      final y = size.height * (-0.05 - 0.25 * local + p.vy * 1.6 * local * local);
      final x = size.width * (p.x + p.vx * local);
      final fade = local > 0.75 ? (1 - local) / 0.25 : 1.0;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
