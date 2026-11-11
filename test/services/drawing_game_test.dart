import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/drawing_room.dart';
import 'package:thinkcraft_word_battle/models/sketch.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_client.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_codec.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_engine.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_host.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

const host = DrawingEngine.hostId;

/// A host engine with [guests] players joined and ready.
DrawingEngine engineWith(int guests, {DrawingSettings? settings}) {
  final engine = DrawingEngine(random: Random(2))
    ..createRoom(
      hostName: 'Sam',
      avatarIndex: 0,
      capacity: 8,
      settings: settings ?? DrawingSettings(rounds: 1),
    );
  for (var number = 1; number <= guests; number++) {
    final id = engine.addPlayer(name: 'P$number', avatarIndex: number);
    engine.setReady(id, true);
  }
  return engine;
}

void main() {
  group('engine', () {
    test('the lobby needs two ready players to start', () {
      final engine = DrawingEngine(random: Random(1))
        ..createRoom(
          hostName: 'Sam',
          avatarIndex: 0,
          capacity: 4,
          settings: DrawingSettings(),
        );
      expect(engine.room!.canStart, isFalse);
      final riya = engine.addPlayer(name: 'Riya', avatarIndex: 1);
      expect(engine.room!.canStart, isFalse);
      engine.setReady(riya, true);
      expect(engine.room!.canStart, isTrue);
    });

    test('a full room or a started game turns players away', () {
      final engine = DrawingEngine()
        ..createRoom(
          hostName: 'Sam',
          avatarIndex: 0,
          capacity: 2,
          settings: DrawingSettings(),
        );
      final riya = engine.addPlayer(name: 'Riya', avatarIndex: 1);
      expect(
        () => engine.addPlayer(name: 'Ali', avatarIndex: 2),
        throwsA(isA<JoinRefused>()),
      );
      engine
        ..setReady(riya, true)
        ..startGame(host);
      engine.removePlayer(riya);
      expect(engine.room, isNull, reason: 'fewer than 2 players left');
    });

    test('only the drawer sees the choices, and guessers see a mask', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        final room = engine.room!;
        expect(room.phase, DrawingPhase.choosing);
        expect(room.drawerId, host, reason: 'the host draws first');
        expect(engine.roomFor(host)!.choices, hasLength(3));
        expect(engine.roomFor('guest-1')!.choices, isEmpty);

        engine.chooseWord(host, 0);
        final word = engine.currentWord!;
        expect(engine.roomFor(host)!.word, word);
        expect(engine.roomFor('guest-1')!.word, isNull);
        expect(
          engine.roomFor('guest-1')!.wordMask,
          word.replaceAll(RegExp('[a-z]'), '_'),
        );
      });
    });

    test('scores guessers by order and pays the drawer', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        engine.chooseWord(host, 1);
        final word = engine.currentWord!;

        engine.guess('guest-2', 'not it');
        engine.guess('guest-2', word.toUpperCase());
        engine.guess('guest-1', word);
        expect(engine.room!.phase, DrawingPhase.drawing);
        engine.guess('guest-3', '$word ');

        final room = engine.room!;
        expect(room.phase, DrawingPhase.turnResult);
        expect(room.turnEnd, TurnEnd.allGuessed);
        expect(room.turnPoints, {
          'guest-2': 10,
          'guest-1': 8,
          'guest-3': 6,
          host: 3 * 3 + 2,
        });
        expect(room.scoreOf('guest-2').stars, 1);
        expect(engine.roomFor('guest-1')!.word, word);
      });
    });

    test('the feed shows wrong guesses, hides correct ones, keeps close '
        'ones private', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        engine.chooseWord(host, 0);
        final word = engine.currentWord!;

        engine.guess('guest-1', 'zzzz');
        engine.guess('guest-1', word);
        final feed = engine.roomFor('guest-2')!.feed;
        expect(feed.first.text, 'zzzz');
        expect(feed.last.kind, FeedKind.correct);
        expect(feed.last.text, isEmpty);
        expect(
          engine.roomFor('guest-2')!.word,
          isNull,
          reason: 'still guessing',
        );
      });
    });

    test('rude guesses are never shown', () {
      fakeAsync((async) {
        final engine = engineWith(1)..startGame(host);
        engine.chooseWord(host, 0);
        engine.guess('guest-1', 'crap');
        expect(engine.room!.feed, isEmpty);
      });
    });

    test('hints appear at half time and with a quarter left', () {
      fakeAsync((async) {
        final engine = engineWith(1, settings: DrawingSettings(rounds: 1))
          ..startGame(host);
        // Find a long word among the choices.
        final choices = engine.roomFor(host)!.choices;
        final index = choices.indexWhere((word) => word.length >= 5);
        engine.chooseWord(host, index < 0 ? 0 : index);
        String mask() => engine.roomFor('guest-1')!.wordMask!;
        int shown() => mask().replaceAll(RegExp('[_ ]'), '').length;

        expect(shown(), 0);
        async.elapse(const Duration(seconds: 41));
        expect(shown(), 1);
        async.elapse(const Duration(seconds: 20));
        expect(shown(), DrawingRulesHints.expected(engine.currentWord!));
      });
    });

    test('time running out ends the turn, then the next player draws', () {
      fakeAsync((async) {
        final engine = engineWith(1)..startGame(host);
        engine.chooseWord(host, 0);
        async.elapse(const Duration(seconds: 80));
        expect(engine.room!.phase, DrawingPhase.turnResult);
        expect(engine.room!.turnEnd, TurnEnd.timeUp);
        expect(engine.room!.turnPoints[host], 0);

        async.elapse(DrawingRoom.turnResultTime);
        expect(engine.room!.phase, DrawingPhase.choosing);
        expect(engine.room!.drawerId, 'guest-1');
        expect(engine.room!.turnInRound, 2);
      });
    });

    test('a slow drawer has a word picked for them', () {
      fakeAsync((async) {
        final engine = engineWith(1)..startGame(host);
        async.elapse(DrawingRoom.chooseTime);
        expect(engine.room!.phase, DrawingPhase.drawing);
        expect(engine.currentWord, isNotNull);
      });
    });

    test('the drawer leaving ends the turn with no points', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        engine.chooseWord(host, 0);
        async.elapse(DrawingRoom.turnResultTime);
        // Round order: host, guest-1, guest-2. End the host's turn first.
        async.elapse(const Duration(seconds: 80));
        async.elapse(DrawingRoom.turnResultTime);
        expect(engine.room!.drawerId, 'guest-1');
        engine.chooseWord('guest-1', 0);
        engine.guess('guest-2', engine.currentWord!);
        engine.setAway('guest-1', away: true);

        expect(engine.room!.turnEnd, TurnEnd.drawerLeft);
        expect(engine.room!.turnPoints, isEmpty);
      });
    });

    test('everyone draws once a round; the last round ends the game', () {
      fakeAsync((async) {
        final engine = engineWith(1, settings: DrawingSettings(rounds: 2))
          ..startGame(host);
        void playTurn() {
          engine.chooseWord(engine.room!.drawerId!, 0);
          async.elapse(const Duration(seconds: 80));
          async.elapse(DrawingRoom.turnResultTime);
        }

        playTurn();
        playTurn();
        expect(engine.room!.phase, DrawingPhase.results);
        expect(engine.room!.isGameOver, isFalse);

        engine.nextRound(host);
        expect(engine.room!.phase, DrawingPhase.results);
        engine.nextRound('guest-1');
        expect(engine.room!.phase, DrawingPhase.choosing);
        expect(engine.room!.round, 2);

        playTurn();
        playTurn();
        expect(engine.room!.isGameOver, isTrue);

        engine.newGame(host);
        expect(engine.room!.round, 1);
        expect(engine.room!.scores, isEmpty);
      });
    });

    test("players who don't press Next Round in time leave", () {
      fakeAsync((async) {
        final engine = engineWith(2, settings: DrawingSettings(rounds: 2))
          ..startGame(host);
        for (var turn = 0; turn < 3; turn++) {
          engine.chooseWord(engine.room!.drawerId!, 0);
          async.elapse(const Duration(seconds: 80));
          async.elapse(DrawingRoom.turnResultTime);
        }
        engine.nextRound('guest-1');
        async.elapse(DrawingRoom.nextRoundWait);
        expect(engine.room!.playerOrNull('guest-2'), isNull);
        expect(engine.room!.round, 2);
      });
    });

    test('rooms travel as JSON', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        engine.chooseWord(host, 0);
        engine.guess('guest-1', 'zzzz');
        final view = engine.roomFor('guest-1')!;
        final back = DrawingCodec.decode(DrawingCodec.encode(view));
        expect(back.code, view.code);
        expect(back.phase, DrawingPhase.drawing);
        expect(back.wordMask, view.wordMask);
        expect(back.feed.single.text, 'zzzz');
        expect(back.players.map((player) => player.name), ['Sam', 'P1', 'P2']);
      });
    });
  });

  group('nearby', () {
    test('a guest joins, sees the drawing live, and guesses', () {
      fakeAsync((async) {
        final engine = DrawingEngine(random: Random(4))
          ..createRoom(
            hostName: 'Sam',
            avatarIndex: 0,
            capacity: 4,
            settings: DrawingSettings(rounds: 1),
          );
        final server = MemoryServer();
        final drawingHost = DrawingHost(engine: engine, server: server)
          ..start();
        final guest = DrawingClient(connect: server.connect);

        unawaited(
          guest.join(
            address: 'host',
            port: nearbyGamePort,
            roomCode: engine.room!.code,
            playerName: 'Riya',
            avatarIndex: 2,
          ),
        );
        async.flushMicrotasks();
        expect(guest.room!.players.map((player) => player.name), [
          'Sam',
          'Riya',
        ]);

        unawaited(guest.setReady(true));
        async.flushMicrotasks();
        engine.startGame(host);
        engine.chooseWord(host, 0);
        async.flushMicrotasks();
        expect(guest.room!.phase, DrawingPhase.drawing);
        expect(guest.room!.word, isNull);

        engine
          ..draw(
            host,
            engine.room!.turnId,
            const StrokeStart(colour: 1, size: 1, points: [100, 100]),
          )
          ..draw(host, engine.room!.turnId, const StrokeAdd([200, 200]));
        async.elapse(const Duration(milliseconds: 100));
        expect(guest.sketch.strokes.single.points, [100, 100, 200, 200]);

        unawaited(guest.guess(engine.currentWord!));
        async.flushMicrotasks();
        expect(guest.room!.phase, DrawingPhase.turnResult);
        expect(guest.room!.turnPoints[guest.localPlayerId], 10);

        // The host leaving closes the room for everyone.
        engine.close();
        async.flushMicrotasks();
        expect(guest.room, isNull);
        unawaited(drawingHost.stop());
        guest.dispose();
      });
    });

    test('a guest drawer sends strokes to the host and other guests', () {
      fakeAsync((async) {
        final engine = DrawingEngine(random: Random(4))
          ..createRoom(
            hostName: 'Sam',
            avatarIndex: 0,
            capacity: 4,
            settings: DrawingSettings(rounds: 1),
          );
        final server = MemoryServer();
        DrawingHost(engine: engine, server: server).start();
        final riya = DrawingClient(connect: server.connect);
        final ali = DrawingClient(connect: server.connect);
        for (final (guest, name) in [(riya, 'Riya'), (ali, 'Ali')]) {
          unawaited(
            guest.join(
              address: 'host',
              port: nearbyGamePort,
              roomCode: engine.room!.code,
              playerName: name,
              avatarIndex: 1,
            ),
          );
          async.flushMicrotasks();
          unawaited(guest.setReady(true));
          async.flushMicrotasks();
        }
        engine.startGame(host);
        engine.chooseWord(host, 0);
        async.elapse(const Duration(seconds: 80));
        async.elapse(DrawingRoom.turnResultTime);
        expect(riya.room!.drawerId, riya.localPlayerId);

        unawaited(riya.chooseWord(0));
        async.flushMicrotasks();
        riya.draw(const StrokeStart(colour: 2, size: 0, points: [1, 2]));
        riya.draw(const StrokeAdd([3, 4]));
        expect(riya.sketch.strokes, hasLength(1), reason: 'shown at once');
        async.elapse(const Duration(milliseconds: 100));

        expect(engine.sketch.strokes.single.points, [1, 2, 3, 4]);
        expect(ali.sketch.strokes.single.points, [1, 2, 3, 4]);
        expect(riya.sketch.strokes, hasLength(1), reason: 'not doubled');
      });
    });

    test('a Word Battle phone is turned away', () {
      fakeAsync((async) {
        final engine = DrawingEngine()
          ..createRoom(
            hostName: 'Sam',
            avatarIndex: 0,
            capacity: 4,
            settings: DrawingSettings(),
          );
        final server = MemoryServer();
        DrawingHost(engine: engine, server: server).start();
        late NearbyLink link;
        unawaited(server.connect('host', 1).then((value) => link = value));
        async.flushMicrotasks();
        final replies = <Map<String, Object?>>[];
        link.messages.listen(replies.add);
        link.send({'t': 'join', 'v': 1, 'code': engine.room!.code});
        async.flushMicrotasks();
        expect(replies.single['t'], 'refused');
      });
    });
  });
}

/// How many letters show once every hint is given.
abstract final class DrawingRulesHints {
  static int expected(String word) {
    final letters = word.replaceAll(' ', '').length;
    return letters >= 4 ? 2 : (letters == 3 ? 1 : 0);
  }
}
