import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/state/room_controller.dart';

import 'helpers.dart';

void main() {
  late TestRig rig;
  late ProviderContainer container;
  RoomController controller() => container.read(roomProvider.notifier);
  RoomState state() => container.read(roomProvider);

  final welcome = fixtureJson('welcome');
  final started = fixtureJson('update_started');
  final myId = welcome['playerId'] as String;

  /// The recorded update, with the open decision given to [owner] and a new [decisionId].
  Map<String, dynamic> updateWith({required String decisionId, String? owner, int version = 100}) {
    final copy = fixtureJson('update_started');
    final view = copy['view'] as Map<String, dynamic>;
    final decision = Map<String, dynamic>.from(view['decision'] as Map<String, dynamic>);
    decision['id'] = decisionId;
    decision['playerId'] = owner ?? myId;
    view['decision'] = decision;
    copy['version'] = version;
    return copy;
  }

  /// Joins and receives the welcome. Uses the test's fake clock: inside testWidgets, nothing
  /// asynchronous happens until the test pumps.
  Future<FakeConnection> joined(WidgetTester tester) async {
    await controller().enter('ABCDE', 'Ali');
    final connection = rig.connections.last;
    connection.receive(welcome);
    await tester.pump();
    return connection;
  }

  /// A controller test on Flutter's fake clock. The container is disposed inside the test, so no
  /// timers (the ping, a pending retry) outlive it.
  void controllerTest(String description, Future<void> Function(WidgetTester tester) body) {
    testWidgets(description, (tester) async {
      rig = await TestRig.create();
      container = rig.container();
      try {
        await body(tester);
      } finally {
        container.dispose();
      }
    });
  }

  controllerTest('joins with hello, then remembers the session and shows the room', (tester) async {
    await controller().enter('ABCDE', 'Ali');
    final connection = rig.connections.single;
    expect(connection.url.path, '/parties/room/ABCDE');
    expect(connection.sent.single, {'type': 'hello', 'nickname': 'Ali', 'deviceId': rig.prefs.deviceId});
    expect(rig.prefs.deviceId, matches(RegExp(r'^[0-9a-f]{32}$')));

    connection.receive(welcome);
    connection.receive(started);
    await tester.pump();
    expect(state().status, LinkStatus.connected);
    expect(state().playerId, myId);
    expect(state().view?.round, 1);
    expect(rig.prefs.session?.token, welcome['token']);
  });

  controllerTest('a move disables its controls until the server moves on (PRD §8.6)', (tester) async {
    final connection = await joined(tester);
    connection.receive(updateWith(decisionId: 'q1'));
    await tester.pump();
    expect(state().myDecision?.id, 'q1');

    controller().hit();
    expect(connection.sent.last, {'type': 'hit', 'decisionId': 'q1'});
    expect(state().myDecision, isNull, reason: 'pending');

    controller().hit(); // a double tap sends nothing more
    expect(connection.sent.where((m) => m['type'] == 'hit'), hasLength(1));

    connection.receive(updateWith(decisionId: 'q1', version: 101)); // an unrelated update
    await tester.pump();
    expect(state().myDecision, isNull, reason: 'still pending');

    connection.receive(updateWith(decisionId: 'q2', version: 102));
    await tester.pump();
    expect(state().myDecision?.id, 'q2');
  });

  controllerTest('STALE clears the pending move without bothering the player', (tester) async {
    final connection = await joined(tester);
    connection.receive(updateWith(decisionId: 'q1'));
    await tester.pump();
    controller().stay();
    connection.receive({'type': 'error', 'code': 'STALE'});
    await tester.pump();
    expect(state().pendingDecisionId, isNull);
    expect(state().notice, isNull);
  });

  controllerTest('a refused or removed player sees a final error, and the session is forgotten', (tester) async {
    final connection = await joined(tester);
    expect(rig.prefs.session, isNotNull);
    connection.receive({'type': 'error', 'code': 'REMOVED'});
    await connection.drop(4000);
    await tester.pump();
    expect(state().error, 'REMOVED');
    expect(state().status, LinkStatus.closed);
    expect(rig.prefs.session, isNull);
    await tester.pump(const Duration(seconds: 30));
    expect(rig.connections, hasLength(1), reason: 'no reconnecting after a final close');
  });

  controllerTest('other errors are one-off notices', (tester) async {
    final connection = await joined(tester);
    connection.receive({'type': 'error', 'code': 'NOT_HOST'});
    await tester.pump();
    expect(state().notice?.code, 'NOT_HOST');
    expect(state().error, isNull);
  });

  controllerTest('a dropped connection reconnects with the token, with backoff (PRD §9.2)', (tester) async {
    final connection = await joined(tester);
    await connection.drop(1006);
    await tester.pump();
    expect(state().status, LinkStatus.reconnecting);

    await tester.pump(const Duration(milliseconds: 499));
    expect(rig.connections, hasLength(1));
    await tester.pump(const Duration(milliseconds: 2));
    expect(rig.connections, hasLength(2));
    expect(rig.connections.last.sent.single['token'], welcome['token']);

    rig.connections.last.receive(welcome);
    await tester.pump();
    expect(state().status, LinkStatus.connected);
  });

  controllerTest('gives up after 2 minutes without a connection', (tester) async {
    final connection = await joined(tester);
    rig.offline = true;
    await connection.drop(1006);
    await tester.pump();
    for (var i = 0; i < 40 && state().error == null; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(state().error, 'CONNECTION_LOST');
    expect(state().status, LinkStatus.closed);
  });

  controllerTest('pings every 20 seconds to keep the connection alive', (tester) async {
    final connection = await joined(tester);
    await tester.pump(const Duration(seconds: 41));
    expect(connection.raw, ['ping', 'ping']);
  });

  controllerTest('quitting tells the server, forgets the session and resets', (tester) async {
    final connection = await joined(tester);
    await controller().quit();
    expect(connection.sent.last, {'type': 'quit'});
    expect(connection.closedByApp, isTrue);
    expect(rig.prefs.session, isNull);
    expect(state().code, isNull);
  });
}
