import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/state/room_controller.dart';

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
  });

  testWidgets('every main screen lays out without overflow at 1.3× text', (tester) async {
    for (final fixture in ['lobby', 'game', 'game-choose', 'round-over', 'results']) {
      final rig = await TestRig.create({'nickname': 'عبدالله'});
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, rig: rig, location: '/room/K7Q2M', fixture: fixture);
      expect(tester.takeException(), isNull, reason: fixture);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
