// Plays a recorded round through the real table director, at game pace, for watching the
// animations and measuring them (PRD §6.0). Screen gallery only: `#/?screen=replay` (add
// `&stats=1` for frame times). It loops.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/protocol.dart';
import '../state/room_controller.dart';
import '../state/table_director.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'replays/worst_case.dart';

/// A room controller whose state the replay sets, update by update.
class ReplayRoomController extends RoomController {
  @override
  RoomState build() => const RoomState();

  @override
  Future<void> enter(String code, String nickname) async {}

  void show(RoomState next) => state = next;
}

class _Recorded {
  _Recorded(Map<String, dynamic> json)
    : now = json['now'] as int,
      view = RoomView.fromJson(json['view'] as Map<String, dynamic>),
      events = [
        for (final e in (json['events'] as List<dynamic>).cast<Map<String, dynamic>>())
          GameEvent(e['type'] as String, e),
      ];

  final int now;
  final RoomView view;
  final List<GameEvent> events;
}

/// Feeds the recorded updates to the room and the table director, waiting for each to finish
/// playing (plus a moment, as a player would) before the next.
class ReplayDriver extends ConsumerStatefulWidget {
  const ReplayDriver({super.key, required this.child, this.stats = false});

  final Widget child;
  final bool stats;

  @override
  ConsumerState<ReplayDriver> createState() => _ReplayDriverState();
}

class _ReplayDriverState extends ConsumerState<ReplayDriver> {
  late final Map<String, dynamic> _json = jsonDecode(worstCaseReplay) as Map<String, dynamic>;
  late final String _me = _json['playerId'] as String;
  late final _Recorded _before = _Recorded(_json['before'] as Map<String, dynamic>);
  late final List<_Recorded> _updates = [
    for (final u in (_json['updates'] as List<dynamic>).cast<Map<String, dynamic>>()) _Recorded(u),
  ];
  bool _running = true;

  @override
  void initState() {
    super.initState();
    // After the first frame: providers can't change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loop()));
  }

  @override
  void dispose() {
    _running = false;
    super.dispose();
  }

  void _show(_Recorded update, {bool snap = false}) {
    (ref.read(roomProvider.notifier) as ReplayRoomController).show(
      RoomState(
        code: 'K7Q2M',
        status: LinkStatus.connected,
        playerId: _me,
        view: update.view,
        version: 1,
        clockOffsetMs: update.now - DateTime.now().millisecondsSinceEpoch,
      ),
    );
    ref.read(tableDirectorProvider.notifier).receive(update.view, update.events, snap: snap, myId: _me);
  }

  Future<void> _loop() async {
    while (_running) {
      _show(_before, snap: true);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      for (final update in _updates) {
        if (!_running || !mounted) return;
        _show(update);
        // Wait for this update to finish playing, then "think" like a player would.
        while (_running && mounted && !ref.read(tableDirectorProvider.notifier).idle) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.stats ? Stack(children: [widget.child, const _FrameStats()]) : widget.child;
}

/// Frame times while the replay runs: how many frames missed 16 ms, and the slowest ones.
class _FrameStats extends StatefulWidget {
  const _FrameStats();

  @override
  State<_FrameStats> createState() => _FrameStatsState();
}

class _FrameStatsState extends State<_FrameStats> {
  final _build = <int>[];
  final _raster = <int>[];
  final _intervals = <int>[];
  Duration? _last;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
    }
  }

  void _onFrame(Duration stamp) {
    final last = _last;
    _last = stamp;
    if (last == null) return;
    final gap = (stamp - last).inMicroseconds;
    // Only frames drawn back to back count: an idle screen draws no frames at all.
    if (gap < 250000) _intervals.add(gap);
  }

  @override
  void dispose() {
    _refresh?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  static String _summary(String name, List<int> values) {
    if (values.isEmpty) return '$name: -';
    final sorted = [...values]..sort();
    int at(double p) => sorted[((sorted.length - 1) * p).round()];
    final slow = values.where((v) => v > 16700).length;
    String ms(int us) => (us / 1000).toStringAsFixed(1);
    return '$name p50 ${ms(at(0.5))} p90 ${ms(at(0.9))} p99 ${ms(at(0.99))} max ${ms(sorted.last)} ms · '
        '>16.7 ms: ${(100 * slow / values.length).toStringAsFixed(1)}% of ${values.length}';
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 8,
    right: 8,
    bottom: 8,
    child: IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(8),
        color: AppColors.scrim,
        child: Text(
          [_summary('frame gap', _intervals), _summary('build', _build), _summary('raster', _raster)].join('\n'),
          textDirection: TextDirection.ltr,
          style: AppText.caption.copyWith(color: AppColors.onTable, fontSize: 11),
        ),
      ),
    ),
  );
}
