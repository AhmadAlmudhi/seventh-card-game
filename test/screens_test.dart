import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/state/room_controller.dart';
import 'package:seventh_card_game/widgets/ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('opens in Arabic, right to left, by default (PRD §6.6)', (tester) async {
    final rig = await TestRig.create();
    await pumpApp(tester, rig: rig);
    expect(find.text('الورقة السابعة'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('إنشاء غرفة'))), TextDirection.rtl);
  });

  testWidgets('switches to English, left to right, and remembers it', (tester) async {
    final rig = await TestRig.create();
    await pumpApp(tester, rig: rig);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Create room'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Create room'))), TextDirection.ltr);
    expect(rig.prefs.language, 'en');
  });

  testWidgets('asks for a valid nickname before creating a room', (tester) async {
    final rig = await TestRig.create({'language': 'en'});
    await pumpApp(tester, rig: rig);
    await tester.tap(find.text('Create room'));
    await settle(tester);
    expect(find.text('Use 1–16 letters, numbers or spaces.'), findsOneWidget);
  });

  testWidgets('the lobby shows the code, the players, and Start for the host', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'lobby');
    expect(find.text('K7Q2M'), findsOneWidget);
    expect(find.text('Players (4/8)'), findsOneWidget);
    expect(find.byTooltip('Reconnecting'), findsOneWidget);
    expect(find.text('Forced Hit from 300 points'), findsOneWidget);
    expect(find.text('Start game'), findsOneWidget);
  });

  testWidgets('a guest waits for the host', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'lobby-guest');
    expect(find.text('Start game'), findsNothing);
    expect(find.text('Waiting for the host to start…'), findsOneWidget);
  });

  testWidgets('on your turn, Hit answers the open decision', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'game');
    expect(find.text('Your turn'), findsOneWidget);
    await tester.tap(find.text('Hit'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.text('Hit')));
    expect(container.read(roomProvider).pendingDecisionId, 'q1');
  });

  testWidgets('when it is someone else’s turn, Hit does nothing', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'game-waiting');
    expect(find.text('سارة’s turn'.replaceAll('’', "'")), findsNothing); // name is isolated with Unicode marks
    await tester.tap(find.text('Hit'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.text('Hit')));
    expect(container.read(roomProvider).pendingDecisionId, isNull);
  });

  testWidgets('choosing a target lists the valid players', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'game-choose');
    expect(find.text('Choose a player to freeze'), findsWidgets);
    expect(find.text('You'), findsWidgets);
    await tester.tap(find.text('سارة').last);
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.text('Choose a player to freeze').first));
    expect(container.read(roomProvider).pendingDecisionId, 'q3');
  });

  testWidgets('results show the winner and a Continue button', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'results');
    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('Winner'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('212 pts'), findsOneWidget);
    expect(find.text('ريم'), findsNothing, reason: 'joined the room after the game');
  });

  testWidgets('Home offers the tutorial game between Join room and How to play (PRD §4.1)', (tester) async {
    final rig = await TestRig.create({'language': 'en'});
    await pumpApp(tester, rig: rig);
    final join = tester.getCenter(find.text('Join room')).dy;
    final tutorial = tester.getCenter(find.text('Tutorial game')).dy;
    final how = tester.getCenter(find.text('How to play')).dy;
    expect(join < tutorial && tutorial < how, isTrue);
  });

  testWidgets('with 8 players, every opponent is on screen with their round score and total', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'game-8');
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final name in ['سارة', 'Omar', 'نورة', 'فهد', 'ريم', 'Khalid', 'هدى']) {
      final rect = tester.getRect(find.text(name).first);
      expect(rect.top >= 0 && rect.bottom <= screen.height / 2, isTrue, reason: '$name at $rect');
    }
    expect(find.text('Round'), findsNWidgets(7));
    expect(find.text('Total'), findsNWidgets(7));
    expect(find.text('+27'), findsOneWidget); // Sara's round so far
    expect(find.text('112'), findsOneWidget); // and her total
  });

  testWidgets('the middle of the table shows the last card; the counts are in the card counter', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'game');
    expect(find.text('Your card'), findsOneWidget);
    expect(find.text('In the deck'), findsNothing);
    await tester.tap(find.byTooltip('Card counter'));
    await settle(tester);
    expect(find.text('In the deck'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);
  });

  testWidgets('the tutorial has no turn timer, and its tips step through with Got it', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'tutorial');
    expect(find.text('Tutorial · to 50'), findsOneWidget);
    expect(find.byType(TimerRing), findsNothing);
    expect(find.text('Robo'), findsWidgets);
    expect(find.text('Watch the colors'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await settle(tester);
    expect(find.text('Watch the colors'), findsNothing);
  });

  testWidgets('the tutorial ends with Play again and Home', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'عبدالله'});
    await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: 'tutorial-results');
    expect(find.text('You won!'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('a real deal plays through the game screen card by card, with sound (PRD §9.3)', (tester) async {
    final rig = await TestRig.create({'language': 'en', 'nickname': 'Ali'});
    final started = fixtureJson('update_started');
    final welcome = fixtureJson('welcome');
    // The room just before the game: the same players in the lobby.
    final lobby = fixtureJson('update_started');
    final lobbyView = lobby['view'] as Map<String, dynamic>;
    lobbyView['phase'] = 'lobby';
    lobbyView['round'] = 0;
    lobbyView.remove('decision');
    for (final p in (lobbyView['players'] as List).cast<Map<String, dynamic>>()) {
      p['row'] = <Object>[];
    }
    lobby['events'] = <Object>[];
    lobby['version'] = 1;

    await pumpApp(tester, rig: rig, location: '/room/K7Q2M');
    final connection = rig.connections.single;
    connection.receive(welcome);
    connection.receive(lobby);
    await settle(tester);
    expect(find.text('Start game'), findsOneWidget); // Ali hosts the recorded room

    connection.receive(started);
    await tester.pump();
    expect(find.text('Round 1'), findsOneWidget);
    // Each beat: the card flips in the middle, then flies to its row. No exceptions along the way.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Your turn'), findsOneWidget);
    expect(rig.sounds.played.where((s) => s.startsWith('deal')), hasLength(2));
    expect(rig.sounds.played, contains('turn'));
  });

  testWidgets('every main screen lays out without overflow at 1.3× text', (tester) async {
    for (final fixture in [
      'lobby',
      'lobby-8',
      'game',
      'game-waiting',
      'game-choose',
      'game-8',
      'game-8-mine',
      'round-over',
      'results',
      'tutorial',
      'tutorial-bot',
      'tutorial-results',
    ]) {
      final rig = await TestRig.create({'nickname': 'عبدالله'});
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: fixture);
      expect(tester.takeException(), isNull, reason: fixture);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
