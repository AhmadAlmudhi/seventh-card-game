import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// A room couldn't be created. [code] is shown in the player's language: `SERVERS_BUSY` when the
/// free plan's daily limit is used up or the server is overloaded (PRD §10.2), `NETWORK` when the
/// server can't be reached.
class RoomApiException implements Exception {
  const RoomApiException(this.code);

  final String code;
}

class RoomApi {
  RoomApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Creates a room and returns its code (PRD §4.2).
  Future<String> createRoom() async {
    final http.Response response;
    try {
      response = await _client.post(Uri.parse('${AppConfig.httpBase}/api/rooms')).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const RoomApiException('NETWORK');
    }
    if (response.statusCode == 201) {
      return (jsonDecode(response.body) as Map<String, dynamic>)['code'] as String;
    }
    if (response.statusCode == 429 || response.statusCode >= 500) throw const RoomApiException('SERVERS_BUSY');
    throw const RoomApiException('GENERIC');
  }
}

final roomApiProvider = Provider<RoomApi>((ref) => RoomApi());
