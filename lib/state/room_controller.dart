import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../net/protocol.dart';
import '../net/room_connection.dart';
import 'prefs.dart';

enum LinkStatus { idle, connecting, connected, reconnecting, closed }

/// A one-off message for the player (for example "Only the host can do that"). [id] makes each
/// notice distinct, so the same code twice still shows twice.
class RoomNotice {
  const RoomNotice(this.code, this.id);

  final String code;
  final int id;
}

const _unset = Object();

@immutable
class RoomState {
  const RoomState({
    this.code,
    this.status = LinkStatus.idle,
    this.playerId,
    this.view,
    this.version = 0,
    this.clockOffsetMs = 0,
    this.error,
    this.notice,
    this.pendingDecisionId,
    this.lastEvents = const [],
  });

  final String? code;
  final LinkStatus status;
  final String? playerId;
  final RoomView? view;
  final int version;

  /// Server clock minus this device's clock, so deadlines show correctly (PRD §8.5.1).
  final int clockOffsetMs;

  /// A final error that ends this visit to the room: a refused join, removal, a lost seat or a lost
  /// connection. The screen shows it with a way home.
  final String? error;
  final RoomNotice? notice;

  /// The decision this player just answered. Its controls stay disabled until the server moves on
  /// (PRD §8.6).
  final String? pendingDecisionId;

  /// The events from the latest update, for animations (M5).
  final List<GameEvent> lastEvents;

  PlayerView? get me => view?.player(playerId);
  bool get isHost => playerId != null && view?.hostId == playerId;

  /// The open decision, if it's this player's to make and not already answered.
  Decision? get myDecision {
    final decision = view?.decision;
    if (decision == null || decision.playerId != playerId || decision.id == pendingDecisionId) return null;
    if (view?.phase != Phase.dealing && view?.phase != Phase.turns) return null;
    return decision;
  }

  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockOffsetMs;

  RoomState copyWith({
    Object? code = _unset,
    LinkStatus? status,
    Object? playerId = _unset,
    Object? view = _unset,
    int? version,
    int? clockOffsetMs,
    Object? error = _unset,
    Object? notice = _unset,
    Object? pendingDecisionId = _unset,
    List<GameEvent>? lastEvents,
  }) => RoomState(
    code: code == _unset ? this.code : code as String?,
    status: status ?? this.status,
    playerId: playerId == _unset ? this.playerId : playerId as String?,
    view: view == _unset ? this.view : view as RoomView?,
    version: version ?? this.version,
    clockOffsetMs: clockOffsetMs ?? this.clockOffsetMs,
    error: error == _unset ? this.error : error as String?,
    notice: notice == _unset ? this.notice : notice as RoomNotice?,
    pendingDecisionId: pendingDecisionId == _unset ? this.pendingDecisionId : pendingDecisionId as String?,
    lastEvents: lastEvents ?? this.lastEvents,
  );
}

/// Error codes that end this visit to the room. Everything else is a one-off notice.
const _finalErrors = {
  'ROOM_NOT_FOUND',
  'ROOM_FULL',
  'GAME_STARTED',
  'ROOM_BUSY',
  'NICKNAME_TAKEN',
  'INVALID_NICKNAME',
  'REMOVED',
  'SEAT_LOST',
  'RATE_LIMITED',
};

/// Reconnect delays (PRD §9.2): 0.5 s, 1 s, 2 s, 4 s, then every 5 s, for up to 2 minutes.
const _retryDelays = [500, 1000, 2000, 4000];
const _retryEveryMs = 5000;
const _giveUpAfter = Duration(minutes: 2);
const _pingEvery = Duration(seconds: 20);

/// The room the player is in: its connection, the latest view, and the player's moves.
class RoomController extends Notifier<RoomState> {
  RoomConnection? _connection;
  StreamSubscription<Object?>? _subscription;
  Timer? _ping;
  Timer? _retry;

  /// Total backoff since the connection dropped. Counting scheduled delays (not wall time) keeps
  /// this deterministic; if the server ends the seat first, the reconnect gets `SEAT_LOST` anyway.
  int _retryElapsedMs = 0;
  int _attempt = 0;
  String _nickname = '';
  String? _token;
  bool _leaving = false;
  int _noticeId = 0;
  AppLifecycleListener? _lifecycle;

  @override
  RoomState build() {
    ref.onDispose(() {
      _teardown();
      _lifecycle?.dispose();
    });
    return const RoomState();
  }

  Prefs get _prefs => ref.read(prefsProvider);

  /// Joins room [code], or reconnects if this device has a session for it. Does nothing if
  /// already in that room.
  Future<void> enter(String code, String nickname) async {
    final active =
        state.code == code &&
        state.error == null &&
        state.status != LinkStatus.closed &&
        state.status != LinkStatus.idle;
    if (active) return;
    _teardown();
    _nickname = nickname;
    final session = _prefs.session;
    _token = session?.roomCode == code ? session!.token : null;
    _leaving = false;
    _attempt = 0;
    _retryElapsedMs = 0;
    _lifecycle ??= _createLifecycleListener();
    state = RoomState(code: code, status: LinkStatus.connecting);
    await _open();
  }

  AppLifecycleListener? _createLifecycleListener() {
    try {
      // When the app comes back to the foreground, reconnect at once (PRD §9.2).
      return AppLifecycleListener(onResume: _reconnectNow, onShow: _reconnectNow);
    } catch (_) {
      return null; // No widgets binding (plain unit tests).
    }
  }

  Future<void> _open() async {
    final code = state.code;
    if (code == null || _leaving) return;
    try {
      final connection = await ref.read(roomConnectorProvider)(Uri.parse('${AppConfig.serverUrl}/parties/room/$code'));
      if (state.code != code || _leaving) {
        await connection.close();
        return;
      }
      _connection = connection;
      _subscription = connection.messages.listen(_onMessage, onDone: _onDone, onError: (_) {});
      connection.send({
        'type': 'hello',
        'nickname': _nickname,
        'deviceId': _prefs.deviceId,
        if (_token != null) 'token': _token,
      });
      _ping = Timer.periodic(_pingEvery, (_) => _connection?.sendRaw('ping'));
    } catch (_) {
      _connectionDropped();
    }
  }

  void _onMessage(Object? data) {
    switch (ServerMessage.parse(data)) {
      case WelcomeMessage(:final playerId, :final token, :final roomCode):
        _token = token;
        _attempt = 0;
        _retryElapsedMs = 0;
        _prefs.setSession(Session(roomCode: roomCode, token: token));
        state = state.copyWith(status: LinkStatus.connected, playerId: playerId);
      case UpdateMessage(:final version, :final serverNow, :final events, :final view):
        if (version < state.version) return; // An older update arriving late.
        final pending = state.pendingDecisionId;
        final stillOpen = pending != null && view.decision?.id == pending;
        state = state.copyWith(
          view: view,
          version: version,
          clockOffsetMs: serverNow - DateTime.now().millisecondsSinceEpoch,
          lastEvents: events,
          pendingDecisionId: stillOpen ? pending : null,
        );
      case ErrorMessage(:final code):
        if (_finalErrors.contains(code)) {
          _prefs.setSession(null);
          state = state.copyWith(error: code, pendingDecisionId: null);
        } else if (code == 'STALE') {
          state = state.copyWith(pendingDecisionId: null); // The latest view already shows what happened.
        } else {
          state = state.copyWith(notice: RoomNotice(code, ++_noticeId), pendingDecisionId: null);
        }
      case null:
        break; // `pong`, or something this version doesn't know.
    }
  }

  void _onDone() {
    final closeCode = _connection?.closeCode;
    _stopConnection();
    if (_leaving || state.error != null || CloseCodes.isFinal(closeCode)) {
      state = state.copyWith(status: LinkStatus.closed);
      return;
    }
    _connectionDropped();
  }

  /// The connection dropped unexpectedly: retry with backoff, keeping the seat (PRD §9.2).
  void _connectionDropped() {
    if (_leaving) return;
    if (_retryElapsedMs >= _giveUpAfter.inMilliseconds) {
      state = state.copyWith(status: LinkStatus.closed, error: 'CONNECTION_LOST');
      return;
    }
    final delay = _attempt < _retryDelays.length ? _retryDelays[_attempt] : _retryEveryMs;
    _attempt++;
    _retryElapsedMs += delay;
    state = state.copyWith(status: LinkStatus.reconnecting);
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: delay), _open);
  }

  void _reconnectNow() {
    if (state.status != LinkStatus.reconnecting || _connection != null) return;
    _retry?.cancel();
    _attempt = 0;
    _open();
  }

  void _send(Map<String, Object?> message) => _connection?.send(message);

  // ---------------------------------------------------------------------------
  // Moves
  // ---------------------------------------------------------------------------

  void hit() => _answer((d) => {'type': 'hit', 'decisionId': d.id}, kind: DecisionKind.hitOrStay);

  void stay() => _answer((d) => {'type': 'stay', 'decisionId': d.id}, kind: DecisionKind.hitOrStay);

  void choose(String targetId) => _answer((d) => {'type': 'choose', 'decisionId': d.id, 'targetId': targetId});

  void _answer(Map<String, Object?> Function(Decision) message, {DecisionKind? kind}) {
    final decision = state.myDecision;
    if (decision == null || (kind != null && decision.kind != kind)) return;
    _send(message(decision));
    state = state.copyWith(pendingDecisionId: decision.id);
  }

  void changeSettings(GameMode mode, int targetScore) =>
      _send({'type': 'settings', 'mode': mode == GameMode.hard ? 'hard' : 'normal', 'targetScore': targetScore});

  void start() => _send({'type': 'start'});

  void continueToRoom() => _send({'type': 'continue'});

  void remove(String playerId) => _send({'type': 'remove', 'playerId': playerId});

  /// Quit the game, or leave the room (PRD §4.6, Rules §12.4).
  Future<void> quit() async {
    _leaving = true;
    _send({'type': 'quit'});
    await _prefs.setSession(null);
    _teardown();
    state = const RoomState();
  }

  /// Forget this room locally, after a final error.
  void reset() {
    _leaving = true;
    _teardown();
    state = const RoomState();
  }

  void clearNotice() => state = state.copyWith(notice: null);

  void _stopConnection() {
    _ping?.cancel();
    _ping = null;
    _subscription?.cancel();
    _subscription = null;
    _connection = null;
  }

  void _teardown() {
    _retry?.cancel();
    _retry = null;
    final connection = _connection;
    _stopConnection();
    connection?.close();
  }
}

final roomProvider = NotifierProvider<RoomController, RoomState>(RoomController.new);
