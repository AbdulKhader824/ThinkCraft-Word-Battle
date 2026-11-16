import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/drawing_room.dart';
import 'package:thinkcraft_word_battle/services/drawing/app_drawing_service.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_client.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_engine.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

import '../../fakes.dart';
import '../../helpers.dart';

/// A drawing service on a pretend network, with a guest phone that can
/// join it.
class _Table {
  _Table() {
    service = AppDrawingService(
      engine: engine,
      finder: finder,
      beacon: beacon,
      startServer: () async => server,
      connect: server.connect,
      findAddress: () async => '192.168.1.5',
    );
  }

  final engine = DrawingEngine(random: Random(3));
  final server = MemoryServer();
  final finder = FakeRoomFinder();
  final beacon = FakeRoomBeacon();
  late final AppDrawingService service;

  /// A friend's phone joins and gets ready.
  Future<DrawingClient> friendJoins(WidgetTester tester, String name) async {
    final guest = DrawingClient(connect: server.connect);
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

Future<void> _openDrawing(WidgetTester tester, _Table table) async {
  await pumpGame(tester, drawing: table.service);
  await goToHome(tester);
  await openRoute(tester, AppRoutes.drawing);
}

void main() {
  testWidgets('the hub card opens Guess the Drawing', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);
    await openRoute(tester, AppRoutes.drawing);

    expect(find.text('Guess the Drawing'), findsOneWidget);
    expect(buttonLabelled('Create Room'), findsOneWidget);
    expect(buttonLabelled('Join Room'), findsOneWidget);
  });

  testWidgets('Create Room has no practice, and asks rounds, time and words', (
    tester,
  ) async {
    final table = _Table();
    await _openDrawing(tester, table);
    await tapAndSettle(tester, buttonLabelled('Create Room'));

    expect(find.byKey(const ValueKey('mode-practice')), findsNothing);
    expect(find.byKey(const ValueKey('mode-nearby')), findsOneWidget);
    expect(find.text('How many players?'), findsOneWidget);
    expect(find.text('How many rounds?'), findsOneWidget);
    expect(find.text('Time to draw'), findsOneWidget);
    expect(find.text('How hard are the words?'), findsOneWidget);
  });

  testWidgets('the host can leave the lobby, which closes the room', (
    tester,
  ) async {
    final table = _Table();
    await _openDrawing(tester, table);
    await tapAndSettle(tester, buttonLabelled('Create Room'));
    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(buttonLabelled('Create Room'));
    await tester.pumpAndSettle();
    await tester.tap(buttonLabelled('Create Room'));
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.drawingLobby,
    );
    await tester.pumpAndSettle();
    expect(currentRoute(tester), AppRoutes.drawingLobby);
    expect(find.text('Leave the game?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave the game?'), findsOneWidget);
    await tester.tap(buttonLabelled('Leave Game'));
    await _waitFor(tester, () => currentRoute(tester) == AppRoutes.home);
    await tester.pumpAndSettle();

    expect(currentRoute(tester), AppRoutes.home);
    expect(table.engine.room, isNull);
    expect(table.beacon.announcing, isFalse);
  });

  testWidgets("each game's Join Room only lists its own rooms", (tester) async {
    const wordBattle = NearbyRoomInfo(
      code: 'ABC234',
      hostName: 'Ali',
      hostAvatar: 1,
      playerCount: 1,
      address: '10.0.0.2',
      port: nearbyGamePort,
    );
    const drawing = NearbyRoomInfo(
      code: 'XYZ789',
      hostName: 'Meera',
      hostAvatar: 2,
      playerCount: 1,
      address: '10.0.0.3',
      port: nearbyGamePort,
      game: NearbyRoomInfo.guessTheDrawing,
    );
    final finder = FakeRoomFinder([wordBattle, drawing]);
    await pumpGame(tester, finder: finder);
    await goToHome(tester);

    await openRoute(tester, AppRoutes.drawingJoin);
    expect(find.text("Meera's room"), findsOneWidget);
    expect(find.text("Ali's room"), findsNothing);

    await openRoute(tester, AppRoutes.joinRoom);
    expect(find.text("Ali's room"), findsOneWidget);
    expect(find.text("Meera's room"), findsNothing);
  });

  testWidgets('a guest sees blanks, guesses, and is told they got it', (
    tester,
  ) async {
    // A friend's phone hosts; this phone joins it.
    final hostEngine = DrawingEngine(random: Random(5))
      ..createRoom(
        hostName: 'Meera',
        avatarIndex: 2,
        capacity: 4,
        settings: DrawingSettings(rounds: 1),
      );
    final table = _Table();
    DrawingHost(engine: hostEngine, server: table.server).start();
    await _openDrawing(tester, table);
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
      () => currentRoute(tester) == AppRoutes.drawingLobby,
    );
    expect(currentRoute(tester), AppRoutes.drawingLobby);

    await tester.pumpAndSettle();
    await tapAndSettle(tester, buttonLabelled("I'm Ready"));
    await _waitFor(tester, () => hostEngine.room!.canStart);
    hostEngine
      ..startGame(DrawingEngine.hostId)
      ..chooseWord(DrawingEngine.hostId, 0);
    await _waitFor(
      tester,
      () => find.text('Meera is drawing').evaluate().isNotEmpty,
    );
    expect(currentRoute(tester), AppRoutes.drawingPlay);
    expect(find.text('Meera is drawing'), findsOneWidget);
    final word = hostEngine.currentWord!;
    expect(find.textContaining('Guess the word'), findsOneWidget);
    expect(find.text(word.toUpperCase()), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('guess-field')), word);
    await tester.tap(find.byKey(const ValueKey('guess-send')));
    await _waitFor(
      tester,
      () => find.text('The word was').evaluate().isNotEmpty,
    );
    expect(find.text('The word was'), findsOneWidget);
    expect(find.text(word.toUpperCase()), findsOneWidget);

    // The host leaves, which closes the room and sends this phone home.
    hostEngine.close();
    await _waitFor(tester, () => currentRoute(tester) == AppRoutes.home);
    expect(currentRoute(tester), AppRoutes.home);
    // A dropped connection waits 2 seconds before trying again, then sees
    // the room has closed and stops.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a whole turn: create, a friend joins, draw, they guess', (
    tester,
  ) async {
    final table = _Table();
    await _openDrawing(tester, table);
    await tapAndSettle(tester, buttonLabelled('Create Room'));
    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tapAndSettle(tester, find.byKey(const ValueKey('round-count-1')));
    await tester.runAsync(() async {
      await tester.tap(buttonLabelled('Create Room'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(currentRoute(tester), AppRoutes.drawingLobby);
    expect(find.text('Waiting for friends to join...'), findsOneWidget);
    expect(find.text('Leave the game?'), findsNothing);
    expect(table.beacon.describe!().game, NearbyRoomInfo.guessTheDrawing);

    final riya = await table.friendJoins(tester, 'Riya');
    await tester.pumpAndSettle();
    expect(find.text('Riya'), findsOneWidget);
    expect(find.text('Everyone is ready!'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Start Game'));
    await pumpFrames(tester);
    expect(currentRoute(tester), AppRoutes.drawingPlay);
    expect(find.text('Pick a word to draw'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('word-choice-0')));
    await pumpFrames(tester);
    final word = table.engine.currentWord!;
    expect(find.text('Draw this!'), findsOneWidget);
    expect(find.text(word.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-undo')), findsOneWidget);

    // Draw a line with a finger.
    final paper = find.bySemanticsLabel(
      'Drawing paper. Draw with your finger.',
    );
    await tester.drag(paper, const Offset(80, 40));
    await pumpFrames(tester);
    expect(table.engine.sketch.strokes, hasLength(1));

    await riya.guess(word);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await pumpFrames(tester);
    expect(table.engine.room!.phase, DrawingPhase.turnResult);
    expect(find.text('Everyone got it!'), findsOneWidget);
    expect(find.text('The word was'), findsOneWidget);
    riya.dispose();
  });
}
