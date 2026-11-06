import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/app.dart';
import 'package:seventh_card_game/dev/fixtures.dart';
import 'package:seventh_card_game/net/room_connection.dart';
import 'package:seventh_card_game/state/prefs.dart';
import 'package:seventh_card_game/state/room_controller.dart';
import 'package:seventh_card_game/state/tutorial_coach.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real server message recorded from a local server (`test/fixtures/`).
Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// Stands in for a WebSocket: records what the app sends, and lets a test play the server.
class FakeConnection implements RoomConnection {
  FakeConnection(this.url);

  final Uri url;
  final _incoming = StreamController<Object?>();
  final sent = <Map<String, Object?>>[];
  final raw = <String>[];
  bool closedByApp = false;

  @override
  int? closeCode;

  @override
  Stream<Object?> get messages => _incoming.stream;

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  @override
  void sendRaw(String text) => raw.add(text);

  @override
  Future<void> close([int code = 1000]) async => closedByApp = true;

  void receive(Object? message) => _incoming.add(message);

  /// The server side closes the socket, optionally with a close code.
  Future<void> drop([int? code]) async {
    closeCode = code;
    await _incoming.close();
  }
}

/// Everything a test needs: saved preferences and a connector that hands out fake connections.
class TestRig {
  TestRig._(this.prefs);

  final Prefs prefs;
  final connections = <FakeConnection>[];

  /// When true, new connections fail, as if the network were down.
  bool offline = false;

  static Future<TestRig> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return TestRig._(Prefs(await SharedPreferences.getInstance()));
  }

  Future<RoomConnection> connect(Uri url) async {
    if (offline) throw const SocketException('offline');
    final connection = FakeConnection(url);
    connections.add(connection);
    return connection;
  }

  List<Override> get overrides => [
    prefsProvider.overrideWithValue(prefs),
    roomConnectorProvider.overrideWithValue(connect),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}

/// Pumps the app at phone size, with an optional fixed room state (and the tutorial tip it shows)
/// and starting route.
Future<void> pumpApp(WidgetTester tester, {required TestRig rig, String location = '/', String? fixture}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...rig.overrides,
        if (fixture != null) roomProvider.overrideWith(() => FixtureRoomController(fixtureState(fixture))),
        if (fixture != null) tutorialCoachProvider.overrideWith(() => FixtureCoach(fixtureCoach(fixture))),
      ],
      child: SeventhCardApp(router: buildRouter(initialLocation: location)),
    ),
  );
  await settle(tester);
}

/// Lets transitions finish. Not pumpAndSettle: spinners and timer rings animate for as long as
/// they're on screen, so the tree never "settles".
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
