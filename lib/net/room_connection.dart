import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One WebSocket to a room. An interface so tests can swap in a fake.
abstract class RoomConnection {
  /// Incoming messages: decoded JSON, or the raw string when it isn't JSON (the `pong` keepalive).
  Stream<Object?> get messages;

  /// The close code once the connection has closed, if the other side sent one.
  int? get closeCode;

  void send(Map<String, Object?> message);

  /// Sends plain text (the `ping` keepalive, PRD §8.5.1).
  void sendRaw(String text);

  Future<void> close([int code = 1000]);
}

typedef RoomConnector = Future<RoomConnection> Function(Uri url);

class WebSocketRoomConnection implements RoomConnection {
  WebSocketRoomConnection._(this._channel);

  final WebSocketChannel _channel;

  static Future<RoomConnection> connect(Uri url) async {
    final channel = WebSocketChannel.connect(url);
    await channel.ready.timeout(const Duration(seconds: 10));
    return WebSocketRoomConnection._(channel);
  }

  @override
  Stream<Object?> get messages => _channel.stream.map((data) {
    if (data is! String) return null;
    try {
      return jsonDecode(data);
    } catch (_) {
      return data;
    }
  });

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void send(Map<String, Object?> message) => _channel.sink.add(jsonEncode(message));

  @override
  void sendRaw(String text) => _channel.sink.add(text);

  @override
  Future<void> close([int code = 1000]) => _channel.sink.close(code);
}

final roomConnectorProvider = Provider<RoomConnector>((ref) => WebSocketRoomConnection.connect);
