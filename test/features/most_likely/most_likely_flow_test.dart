import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/most_likely_room.dart';
import 'package:thinkcraft_word_battle/services/most_likely/app_most_likely_service.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_client.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_engine.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';
import 'package:thinkcraft_word_battle/services/online/online_rooms.dart';

import '../../fakes.dart';
import '../../helpers.dart';
import '../../memory_relay.dart';

const _host = MostLikelyEngine.hostId;

/// A Most Likely To... service on a pretend network, with guest phones
/// that can join it.
class _Table {
  _Table({int seed = 3, OnlineRooms? online})
    : engine = MostLikelyEngine(random: Random(seed)) {
    service = AppMostLikelyService(
      engine: engine,
      finder: finder,
      beacon: beacon,
      startServer: () async => server,
      connect: server.connect,
      findAddress: () async => '192.168.1.5',
      online: online,
    );
  }

  final MostLikelyEngine engine;
  final server = MemoryServer();
  final finder = FakeRoomFinder();
  final beacon = FakeRoomBeacon();
  late final AppMostLikelyService service;

  /// A friend's phone joins and gets ready.
  Future<MostLikelyClient> friendJoins(WidgetTester tester, String name) async {
    final guest = MostLikelyClient(connect: server.connect);
    await tester.runAsync(
      () => guest.join(
        address: 'host',
        port: nearbyGamePort,
        roomCode: engine.room!.code,
        playerName: name,
        avatarIndex: 3,
      ),
    );
    await guest.setReady(true);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    return guest;
  }
}

/// Lets real (in-memory) network messages arrive until [done].
Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var tries = 0; tries < 50 && !done(); tries++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(
  WidgetTester tester,
  _Table table, {
  List<String>? shared,
}) async {
  await pumpGame(tester, mostLikely: table.service, shared: shared);
  await goToHome(tester);
  await openRoute(tester, AppRoutes.mostLikely);
}

/// Creates a room on this phone and waits for the lobby.
Future<void> _createRoom(WidgetTester tester, {bool online = false}) async {
  await tapAndSettle(tester, buttonLabelled('Create Room'));
  await tester.enterText(find.byType(TextFormField).first, 'Sam');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (online) {
    await tapAndSettle(tester, find.byKey(const ValueKey('mode-online')));
  }
  await tester.ensureVisible(buttonLabelled('Create Room'));
  await tester.pumpAndSettle();
  // In real time, so the room's network messages flow while friends join.
  await tester.runAsync(() async {
    await tester.tap(buttonLabelled('Create Room'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await _waitFor(
    tester,
    () => currentRoute(tester) == AppRoutes.mostLikelyLobby,
  );
  await tester.pumpAndSettle();
}

/// Jumps past the current stage's timer, which runs in real time here.
Future<void> _skipTimer(WidgetTester tester, MostLikelyEngine engine) async {
  withClock(Clock.fixed(DateTime(2100)), engine.refresh);
  await pumpFrames(tester);
}

void main() {
  testWidgets('the hub card opens Most Likely To...', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);
    await openRoute(tester, AppRoutes.mostLikely);

    expect(find.text('Most Likely To...'), findsOneWidget);
    expect(buttonLabelled('Create Room'), findsOneWidget);
    expect(buttonLabelled('Join Room'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('How to Play'));
    expect(find.text('3. Vote in secret'), findsOneWidget);
  });

  testWidgets('Create Room asks players, questions and topics', (tester) async {
    final table = _Table();
    await _open(tester, table);
    await tapAndSettle(tester, buttonLabelled('Create Room'));

    expect(find.byKey(const ValueKey('mode-practice')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-2')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-3')), findsOneWidget);
    expect(find.text('How many questions?'), findsOneWidget);
    expect(find.byKey(const ValueKey('question-count-20')), findsOneWidget);
    expect(find.text('Question topics (4 of 4)'), findsOneWidget);

    // A topic can be turned off, but the last one stays.
    for (final topic in ['silly', 'future', 'adventure', 'everyday']) {
      await tester.ensureVisible(find.byKey(ValueKey('topic-$topic')));
      await tapAndSettle(tester, find.byKey(ValueKey('topic-$topic')));
    }
    expect(find.text('Question topics (1 of 4)'), findsOneWidget);
  });

  testWidgets('a whole round on the host phone, then the leaderboard', (
    tester,
  ) async {
    final table = _Table();
    await _open(tester, table);
    await _createRoom(tester);
    expect(find.text('Waiting for 2 more friends to join...'), findsOneWidget);
    expect(table.beacon.describe!().game, NearbyRoomInfo.mostLikelyTo);

    final riya = await table.friendJoins(tester, 'Riya');
    final ali = await table.friendJoins(tester, 'Ali');
    await tester.pumpAndSettle();
    expect(find.text('Everyone is ready!'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Start Game'));
    await pumpFrames(tester);
    expect(currentRoute(tester), AppRoutes.mostLikelyPlay);

    final engine = table.engine;
    for (var number = 1; number <= 5; number++) {
      expect(find.text('Question $number of 10'), findsOneWidget);
      expect(
        find.text('${engine.room!.question}?'),
        findsOneWidget,
        reason: 'the question shows',
      );

      // The host picks themselves; both friends pick Riya.
      await tester.tap(find.byKey(const ValueKey('vote-$_host')));
      await tester.pump();
      await tester.tap(buttonLabelled('Lock vote'));
      await pumpFrames(tester);
      expect(
        find.text('You voted for yourself. Waiting for 2 more...'),
        findsOneWidget,
      );
      for (final guest in [riya, ali]) {
        await guest.vote(riya.localPlayerId!);
      }
      await _waitFor(
        tester,
        () => engine.room!.phase == MostLikelyPhase.reveal,
      );
      await pumpFrames(tester);
      expect(find.text('Riya is most likely! 🎉'), findsOneWidget);
      expect(
        find.text('Not this time. Keep reading the room!'),
        findsOneWidget,
      );
      // Only counts show, never who voted for whom.
      expect(find.textContaining('→'), findsNothing);

      await _skipTimer(tester, engine);
    }

    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.mostLikelyResults,
    );
    await pumpFrames(tester);
    expect(find.text('Round 1 of 2'), findsOneWidget);
    expect(find.text('Mind readers'), findsOneWidget);
    expect(buttonLabelled('Next Round'), findsOneWidget);
    expect(find.text('+5'), findsNWidgets(2));
    riya.dispose();
    ali.dispose();
  });

  testWidgets('a guest joins a friend\'s room and votes', (tester) async {
    // A friend's phone hosts; this phone joins it.
    final hostEngine = MostLikelyEngine(random: Random(8))
      ..createRoom(
        hostName: 'Meera',
        avatarIndex: 2,
        capacity: 4,
        settings: MostLikelySettings(),
      );
    final other = hostEngine.addPlayer(name: 'Zara', avatarIndex: 4);
    hostEngine.setReady(other, true);
    final table = _Table();
    MostLikelyHost(engine: hostEngine, server: table.server).start();
    await _open(tester, table);
    await tapAndSettle(tester, buttonLabelled('Join Room'));
    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      hostEngine.room!.code,
    );
    await tapAndSettle(
      tester,
      find.text("Can't see the room? Type the address"),
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-address')),
      '10.0.0.9',
    );
    await tester.ensureVisible(buttonLabelled('Join Room').last);
    await tester.pump();
    await tester.tap(buttonLabelled('Join Room').last);
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.mostLikelyLobby,
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, buttonLabelled("I'm Ready"));
    await _waitFor(tester, () => hostEngine.room!.canStart);

    hostEngine.startGame(_host);
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.mostLikelyPlay,
    );
    await pumpFrames(tester);
    expect(find.text('${hostEngine.room!.question}?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vote-$_host')));
    await tester.pump();
    await tester.tap(buttonLabelled('Lock vote'));
    final me = hostEngine.room!.players.firstWhere((p) => p.name == 'Sam').id;
    await _waitFor(tester, () => hostEngine.room!.votes[me] == _host);
    await pumpFrames(tester);
    expect(hostEngine.room!.votes[me], _host);
    expect(
      find.text('You voted for Meera. Waiting for 2 more...'),
      findsOneWidget,
    );

    hostEngine.close();
    await _waitFor(tester, () => currentRoute(tester) == AppRoutes.home);
    expect(currentRoute(tester), AppRoutes.home);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('an online room shows the code with Share code', (tester) async {
    final relay = MemoryRelay();
    final table = _Table(
      online: OnlineRooms(
        openSocket: relay.open,
        relay: Uri.parse('wss://relay.example'),
        random: Random(1),
      ),
    );
    final shared = <String>[];
    await _open(tester, table, shared: shared);
    await _createRoom(tester, online: true);

    final code = table.engine.room!.code;
    expect(relay.hasRoom(code), isTrue);
    expect(find.text(code), findsOneWidget);
    expect(table.beacon.announcing, isFalse);

    await tapAndSettle(tester, buttonLabelled('Share code'));
    expect(shared.single, contains(code));
    expect(shared.single, contains('Most Likely To...'));

    await tester.runAsync(table.service.leaveRoom);
    await tester.pumpAndSettle();
  });
}
