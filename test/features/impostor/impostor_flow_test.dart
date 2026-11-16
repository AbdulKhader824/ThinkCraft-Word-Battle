import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/services/impostor/app_impostor_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_client.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

import '../../fakes.dart';
import '../../helpers.dart';

const _host = ImpostorEngine.hostId;

/// An Impostor service on a pretend network, with guest phones that can
/// join it.
class _Table {
  _Table({int seed = 3}) : engine = ImpostorEngine(random: Random(seed)) {
    service = AppImpostorService(
      engine: engine,
      finder: finder,
      beacon: beacon,
      startServer: () async => server,
      connect: server.connect,
      findAddress: () async => '192.168.1.5',
    );
  }

  final ImpostorEngine engine;
  final server = MemoryServer();
  final finder = FakeRoomFinder();
  final beacon = FakeRoomBeacon();
  late final AppImpostorService service;

  /// A friend's phone joins and gets ready.
  Future<ImpostorClient> friendJoins(WidgetTester tester, String name) async {
    final guest = ImpostorClient(connect: server.connect);
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

Future<void> _openImpostor(WidgetTester tester, _Table table) async {
  await pumpGame(tester, impostor: table.service);
  await goToHome(tester);
  await openRoute(tester, AppRoutes.impostor);
}

/// Creates a room on this phone and waits for the lobby.
Future<void> _createRoom(WidgetTester tester) async {
  await tapAndSettle(tester, buttonLabelled('Create Room'));
  await tester.enterText(find.byType(TextFormField).first, 'Sam');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(buttonLabelled('Create Room'));
  await tester.pumpAndSettle();
  // In real time, so the room's network messages flow while friends join.
  await tester.runAsync(() async {
    await tester.tap(buttonLabelled('Create Room'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await _waitFor(tester, () => currentRoute(tester) == AppRoutes.impostorLobby);
  await tester.pumpAndSettle();
}

/// Holds the secret card down, checks what it shows, then lets go.
Future<void> _holdCard(WidgetTester tester, void Function() check) async {
  final card = find.byKey(const ValueKey('secret-card')).first;
  final gesture = await tester.startGesture(tester.getCenter(card));
  await tester.pump();
  check();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('the hub card opens The Impostor', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);
    await openRoute(tester, AppRoutes.impostor);

    expect(find.text('The Impostor'), findsOneWidget);
    expect(buttonLabelled('Create Room'), findsOneWidget);
    expect(buttonLabelled('Join Room'), findsOneWidget);
    expect(buttonLabelled('How to Play'), findsOneWidget);
  });

  testWidgets('Create Room asks players, rounds, clue time, turns and topics', (
    tester,
  ) async {
    final table = _Table();
    await _openImpostor(tester, table);
    await tapAndSettle(tester, buttonLabelled('Create Room'));

    expect(find.byKey(const ValueKey('mode-practice')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-2')), findsNothing);
    expect(find.byKey(const ValueKey('player-count-3')), findsOneWidget);
    expect(find.text('How many rounds?'), findsOneWidget);
    expect(find.text('Time for each clue'), findsOneWidget);
    expect(find.text('Clue turns each'), findsOneWidget);
    expect(find.text('Word topics (7 of 7)'), findsOneWidget);

    // A topic can be turned off, but the last one stays.
    await tapAndSettle(tester, find.byKey(const ValueKey('topic-animals')));
    expect(find.text('Word topics (6 of 7)'), findsOneWidget);
  });

  testWidgets('the host can leave the lobby, which closes the room', (
    tester,
  ) async {
    final table = _Table();
    await _openImpostor(tester, table);
    await _createRoom(tester);
    expect(currentRoute(tester), AppRoutes.impostorLobby);
    expect(find.text('Waiting for 2 more friends to join...'), findsOneWidget);
    expect(table.beacon.describe!().game, NearbyRoomInfo.theImpostor);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(buttonLabelled('Leave Game'));
    await _waitFor(tester, () => currentRoute(tester) == AppRoutes.home);
    await tester.pumpAndSettle();
    expect(currentRoute(tester), AppRoutes.home);
    expect(table.engine.room, isNull);
  });

  testWidgets('a whole round on the host phone', (tester) async {
    final table = _Table();
    await _openImpostor(tester, table);
    await _createRoom(tester);
    final riya = await table.friendJoins(tester, 'Riya');
    final ali = await table.friendJoins(tester, 'Ali');
    await tester.pumpAndSettle();
    expect(find.text('Everyone is ready!'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Start Game'));
    await pumpFrames(tester);
    expect(currentRoute(tester), AppRoutes.impostorPlay);
    expect(find.text('Hold to see your word'), findsOneWidget);

    final engine = table.engine;
    final room = engine.room!;
    final hostIsImpostor = room.impostorId == _host;
    await _holdCard(tester, () {
      if (hostIsImpostor) {
        expect(find.text('You are the Impostor!'), findsOneWidget);
        expect(find.text(room.word!.toUpperCase()), findsNothing);
      } else {
        expect(find.text(room.word!.toUpperCase()), findsOneWidget);
      }
    });
    expect(find.text('Hold to see your word'), findsOneWidget);

    // Everyone gives their clue.
    await tester.pump(ImpostorRoom.wordTime);
    await pumpFrames(tester);
    expect(engine.room!.phase, ImpostorPhase.clues);
    final guests = {riya.localPlayerId: riya, ali.localPlayerId: ali};
    while (engine.room!.phase == ImpostorPhase.clues) {
      final speaker = engine.room!.speakerId!;
      if (speaker == _host) {
        expect(find.text('Your turn! Say a clue out loud.'), findsOneWidget);
        await tester.tap(buttonLabelled('Done'));
      } else {
        await guests[speaker]!.clueDone();
      }
      await _waitFor(tester, () => engine.room!.speakerId != speaker);
    }
    await pumpFrames(tester);
    expect(find.text("Who's the Impostor?"), findsOneWidget);
    await tester.tap(buttonLabelled('Vote now'));
    await pumpFrames(tester);
    expect(find.text('Who is the Impostor?'), findsOneWidget);

    // The host votes for a guest; the guests vote for the Impostor (or
    // the host, if they're it).
    final impostor = engine.room!.impostorId!;
    final suspect = hostIsImpostor ? riya.localPlayerId! : impostor;
    await tester.tap(find.byKey(ValueKey('vote-$suspect')));
    await tester.pump();
    await tester.tap(buttonLabelled('Lock vote'));
    await pumpFrames(tester);
    expect(find.text('Vote locked!'), findsOneWidget);
    for (final guest in [riya, ali]) {
      final id = guest.localPlayerId!;
      await guest.vote(id == impostor ? _host : impostor);
    }
    await _waitFor(tester, () => engine.room!.phase == ImpostorPhase.reveal);
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('reveal-result')), findsOneWidget);

    // The Impostor guesses the word.
    // The reveal's timer runs in real time here, so jump the clock past
    // it instead of waiting 8 seconds.
    withClock(Clock.fixed(DateTime(2100)), engine.refresh);
    await _waitFor(
      tester,
      () => find.byKey(const ValueKey('guess-0')).evaluate().isNotEmpty,
    );
    await pumpFrames(tester);
    expect(engine.room!.phase, ImpostorPhase.guess);
    final word = engine.room!.word!;
    if (hostIsImpostor) {
      expect(find.text('Guess the word!'), findsOneWidget);
      await tester.tap(find.text(word.toUpperCase()));
    } else {
      expect(find.textContaining('is guessing the word'), findsOneWidget);
      await guests[impostor]!.guessWord(word);
    }
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.impostorResults,
    );
    await pumpFrames(tester);

    expect(currentRoute(tester), AppRoutes.impostorResults);
    expect(find.byKey(const ValueKey('results-word')), findsOneWidget);
    expect(find.textContaining('guessed it'), findsOneWidget);
    expect(buttonLabelled('Next Round'), findsOneWidget);
    riya.dispose();
    ali.dispose();
  });

  testWidgets('a guest sees their word, or that they are the Impostor', (
    tester,
  ) async {
    // A friend's phone hosts; this phone joins it.
    final hostEngine = ImpostorEngine(random: Random(8))
      ..createRoom(
        hostName: 'Meera',
        avatarIndex: 2,
        capacity: 4,
        settings: ImpostorSettings(rounds: 3, clueTurns: 1),
      );
    final other = hostEngine.addPlayer(name: 'Zara', avatarIndex: 4);
    hostEngine.setReady(other, true);
    final table = _Table();
    ImpostorHost(engine: hostEngine, server: table.server).start();
    await _openImpostor(tester, table);
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
      () => currentRoute(tester) == AppRoutes.impostorLobby,
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, buttonLabelled("I'm Ready"));
    await _waitFor(tester, () => hostEngine.room!.canStart);

    hostEngine.startGame(_host);
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.impostorPlay,
    );
    await pumpFrames(tester);
    final room = hostEngine.room!;
    final me = room.players.firstWhere((p) => p.name == 'Sam').id;
    await _holdCard(tester, () {
      if (room.impostorId == me) {
        expect(find.text('You are the Impostor!'), findsOneWidget);
      } else {
        expect(find.text(room.word!.toUpperCase()), findsOneWidget);
      }
    });

    hostEngine.close();
    await _waitFor(tester, () => currentRoute(tester) == AppRoutes.home);
    expect(currentRoute(tester), AppRoutes.home);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
