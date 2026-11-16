import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_client.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_codec.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

const host = ImpostorEngine.hostId;

/// A host engine with [guests] players joined and ready.
ImpostorEngine engineWith(int guests, {ImpostorSettings? settings, int? seed}) {
  final engine = ImpostorEngine(random: Random(seed ?? 2))
    ..createRoom(
      hostName: 'Sam',
      avatarIndex: 0,
      capacity: 8,
      settings: settings ?? ImpostorSettings(rounds: 3, clueTurns: 1),
    );
  for (var number = 1; number <= guests; number++) {
    final id = engine.addPlayer(name: 'P$number', avatarIndex: number);
    engine.setReady(id, true);
  }
  return engine;
}

/// Plays from the word through to the vote, everyone tapping Done.
void toVote(ImpostorEngine engine, FakeAsync async) {
  async.elapse(ImpostorRoom.wordTime);
  while (engine.room!.phase == ImpostorPhase.clues) {
    engine.clueDone(engine.room!.speakerId!);
  }
  engine.voteNow(host);
}

void main() {
  group('engine', () {
    test('the lobby needs three ready players', () {
      final engine = engineWith(1);
      expect(engine.room!.canStart, isFalse);
      final riya = engine.addPlayer(name: 'Riya', avatarIndex: 2);
      expect(engine.room!.canStart, isFalse);
      engine.setReady(riya, true);
      expect(engine.room!.canStart, isTrue);
    });

    test('a full room or a started game turns players away', () {
      final engine = ImpostorEngine()
        ..createRoom(
          hostName: 'Sam',
          avatarIndex: 0,
          capacity: 3,
          settings: ImpostorSettings(),
        );
      engine
        ..addPlayer(name: 'A', avatarIndex: 1)
        ..addPlayer(name: 'B', avatarIndex: 2);
      expect(
        () => engine.addPlayer(name: 'C', avatarIndex: 3),
        throwsA(isA<JoinRefused>()),
      );
    });

    test('only the Impostor misses the word, and only they know', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        final room = engine.room!;
        expect(room.phase, ImpostorPhase.word);
        final impostor = room.impostorId!;
        for (final player in room.players) {
          final view = engine.roomFor(player.id)!;
          expect(view.topic, room.topic);
          if (player.id == impostor) {
            expect(view.isImpostor, isTrue);
            expect(view.word, isNull);
            expect(view.impostorId, impostor);
          } else {
            expect(view.isImpostor, isFalse);
            expect(view.word, room.word);
            expect(view.impostorId, isNull);
          }
          expect(view.guessChoices, isEmpty);
        }
      });
    });

    test('clues go round in order, never starting with the Impostor', () {
      fakeAsync((async) {
        final engine = engineWith(
          3,
          settings: ImpostorSettings(rounds: 3, clueTurns: 2),
        )..startGame(host);
        async.elapse(ImpostorRoom.wordTime);
        final room = engine.room!;
        expect(room.phase, ImpostorPhase.clues);
        expect(room.clueOrder, hasLength(8));
        expect(room.speakerId, isNot(room.impostorId));

        // Someone else tapping Done changes nothing.
        final speaker = room.speakerId!;
        final other = room.players.firstWhere((p) => p.id != speaker).id;
        engine.clueDone(other);
        expect(engine.room!.clueIndex, 0);

        engine.clueDone(speaker);
        expect(engine.room!.clueIndex, 1);
        // The timer moves on too.
        async.elapse(room.settings.clueTime);
        expect(engine.room!.clueIndex, 2);
        for (var turn = 2; turn < 8; turn++) {
          engine.clueDone(engine.room!.speakerId!);
        }
        expect(engine.room!.phase, ImpostorPhase.talk);
        async.elapse(ImpostorRoom.talkTime);
        expect(engine.room!.phase, ImpostorPhase.vote);
      });
    });

    test('away players lose their clue turn', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        final room = engine.room!;
        final skipped = room.clueOrder[1];
        if (skipped == room.impostorId) return; // Covered elsewhere.
        engine.setAway(skipped, away: true);
        async.elapse(ImpostorRoom.wordTime);
        engine.clueDone(engine.room!.speakerId!);
        expect(engine.room!.clueIndex, 2);
      });
    });

    test('votes stay secret until the reveal, then the Impostor guesses', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        toVote(engine, async);
        final impostor = engine.room!.impostorId!;
        final others = [
          for (final p in engine.room!.players)
            if (p.id != impostor) p.id,
        ];

        expect(() => engine.vote(others[0], others[0]), returnsNormally);
        expect(engine.room!.votes, isEmpty, reason: 'no voting for yourself');

        engine.vote(others[0], impostor);
        engine.vote(others[0], others[1]);
        expect(engine.room!.votes[others[0]], impostor, reason: 'locked');
        final view = engine.roomFor(others[1])!;
        expect(view.votes, isEmpty);
        expect(view.votedIds, {others[0]});
        expect(engine.roomFor(others[0])!.votes, {others[0]: impostor});

        engine
          ..vote(others[1], impostor)
          ..vote(others[2], others[0])
          ..vote(impostor, others[1]);
        final reveal = engine.roomFor(others[2])!;
        expect(reveal.phase, ImpostorPhase.reveal);
        expect(reveal.caught, isTrue);
        expect(reveal.impostorId, impostor);
        expect(reveal.votes, hasLength(4));
        expect(reveal.word, isNotNull);

        async.elapse(ImpostorRoom.revealTime);
        final guess = engine.roomFor(impostor)!;
        expect(guess.phase, ImpostorPhase.guess);
        expect(guess.guessChoices, hasLength(6));
        expect(guess.word, isNull, reason: 'still secret while guessing');

        // Only the Impostor can guess.
        engine.guessWord(others[0], engine.room!.word!);
        expect(engine.room!.phase, ImpostorPhase.guess);
        engine.guessWord(impostor, engine.room!.word!);

        final results = engine.roomFor(impostor)!;
        expect(results.phase, ImpostorPhase.results);
        expect(results.word, isNotNull);
        expect(results.guessedRight, isTrue);
        expect(results.roundPoints[impostor], 2 + 3, reason: '1 fooled');
        expect(results.roundPoints[others[0]], 3 + 1);
        expect(results.roundPoints[others[2]], 1);
        expect(results.scoreOf(others[0]).rightVotes, 1);
        expect(results.scoreOf(impostor).impostorPoints, 5);
      });
    });

    test('a slow Impostor gets no guess points', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        toVote(engine, async);
        async.elapse(ImpostorRoom.voteTime);
        expect(engine.room!.phase, ImpostorPhase.reveal);
        expect(engine.room!.caught, isFalse, reason: 'nobody voted');
        async.elapse(ImpostorRoom.revealTime);
        async.elapse(ImpostorRoom.guessTime);
        final room = engine.room!;
        expect(room.phase, ImpostorPhase.results);
        expect(room.guessedWord, isNull);
        expect(room.roundPoints[room.impostorId], 3, reason: 'not caught');
      });
    });

    test('the Impostor leaving ends the round with no points', () {
      fakeAsync((async) {
        final engine = engineWith(3, seed: 11)..startGame(host);
        var impostor = engine.room!.impostorId!;
        // The host leaving closes the room, so find a round with a guest.
        while (impostor == host) {
          toVote(engine, async);
          async.elapse(ImpostorRoom.voteTime);
          async.elapse(ImpostorRoom.revealTime);
          async.elapse(ImpostorRoom.guessTime);
          for (final p in engine.room!.players) {
            engine.nextRound(p.id);
          }
          impostor = engine.room!.impostorId!;
        }
        async.elapse(ImpostorRoom.wordTime);
        engine.setAway(impostor, away: true);
        final room = engine.room!;
        expect(room.phase, ImpostorPhase.results);
        expect(room.roundEnd, RoundEnd.impostorLeft);
        expect(room.roundPoints, isEmpty);
      });
    });

    test('fewer than three players closes the room', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        engine.removePlayer('guest-1');
        expect(engine.room, isNull);
      });
    });

    test('rounds go on with Next Round, and the last one ends the game', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        void playRound() {
          toVote(engine, async);
          async.elapse(ImpostorRoom.voteTime);
          async.elapse(ImpostorRoom.revealTime);
          async.elapse(ImpostorRoom.guessTime);
        }

        final words = <String>{};
        for (var round = 1; round <= 3; round++) {
          expect(engine.room!.round, round);
          expect(words.add(engine.room!.word!), isTrue, reason: 'new word');
          playRound();
          if (round < 3) {
            engine
              ..nextRound(host)
              ..nextRound('guest-1');
            expect(engine.room!.phase, ImpostorPhase.results);
            engine.nextRound('guest-2');
          }
        }
        expect(engine.room!.isGameOver, isTrue);
        engine.newGame(host);
        expect(engine.room!.round, 1);
        expect(engine.room!.scores, isEmpty);
      });
    });

    test("players who don't press Next Round in time leave", () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        toVote(engine, async);
        async.elapse(ImpostorRoom.voteTime);
        async.elapse(ImpostorRoom.revealTime);
        async.elapse(ImpostorRoom.guessTime);
        engine
          ..nextRound('guest-1')
          ..nextRound('guest-2');
        async.elapse(ImpostorRoom.nextRoundWait);
        expect(engine.room!.playerOrNull('guest-3'), isNull);
        expect(engine.room!.round, 2);
      });
    });

    test('everyone gets a turn as the Impostor over a long game', () {
      fakeAsync((async) {
        final engine = engineWith(
          2,
          settings: ImpostorSettings(rounds: 8, clueTurns: 1),
          seed: 5,
        )..startGame(host);
        final picked = <String>{};
        for (var round = 1; round <= 8; round++) {
          picked.add(engine.room!.impostorId!);
          toVote(engine, async);
          async.elapse(ImpostorRoom.voteTime);
          async.elapse(ImpostorRoom.revealTime);
          async.elapse(ImpostorRoom.guessTime);
          for (final p in engine.room!.players) {
            engine.nextRound(p.id);
          }
        }
        expect(picked, {host, 'guest-1', 'guest-2'});
      });
    });

    test('rooms travel as JSON', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        toVote(engine, async);
        final voter = engine.room!.players
            .firstWhere((p) => p.id != engine.room!.impostorId)
            .id;
        engine.vote(voter, engine.room!.impostorId!);
        final view = engine.roomFor(voter)!;
        final back = ImpostorCodec.decode(ImpostorCodec.encode(view));
        expect(back.phase, ImpostorPhase.vote);
        expect(back.word, view.word);
        expect(back.topic, view.topic);
        expect(back.votes, view.votes);
        expect(back.votedIds, view.votedIds);
        expect(back.clueOrder, view.clueOrder);
        expect(back.settings.topics, view.settings.topics);
        expect(back.players.map((p) => p.name), ['Sam', 'P1', 'P2', 'P3']);
      });
    });
  });

  group('nearby', () {
    test('guests join, vote and see the result', () {
      fakeAsync((async) {
        final engine = ImpostorEngine(random: Random(4))
          ..createRoom(
            hostName: 'Sam',
            avatarIndex: 0,
            capacity: 4,
            settings: ImpostorSettings(rounds: 3, clueTurns: 1),
          );
        final server = MemoryServer();
        final impostorHost = ImpostorHost(engine: engine, server: server)
          ..start();
        final guests = <ImpostorClient>[];
        for (final name in ['Riya', 'Ali']) {
          final guest = ImpostorClient(connect: server.connect);
          unawaited(
            guest.join(
              address: 'host',
              port: nearbyGamePort,
              roomCode: engine.room!.code,
              playerName: name,
              avatarIndex: 2,
            ),
          );
          async.flushMicrotasks();
          unawaited(guest.setReady(true));
          async.flushMicrotasks();
          guests.add(guest);
        }
        expect(guests[1].room!.players.map((p) => p.name), [
          'Sam',
          'Riya',
          'Ali',
        ]);

        engine.startGame(host);
        async.flushMicrotasks();
        final impostor = engine.room!.impostorId!;
        for (final guest in guests) {
          final mine = guest.room!;
          expect(mine.phase, ImpostorPhase.word);
          expect(mine.isImpostor, guest.localPlayerId == impostor);
          expect(mine.word == null, guest.localPlayerId == impostor);
        }

        async.elapse(ImpostorRoom.wordTime);
        while (engine.room!.phase == ImpostorPhase.clues) {
          final speaker = engine.room!.speakerId!;
          if (speaker == host) {
            engine.clueDone(host);
          } else {
            unawaited(
              guests.firstWhere((g) => g.localPlayerId == speaker).clueDone(),
            );
          }
          async.flushMicrotasks();
        }
        engine.voteNow(host);
        async.flushMicrotasks();
        expect(guests[0].room!.phase, ImpostorPhase.vote);

        final suspect = impostor == host ? guests[0].localPlayerId! : host;
        for (final guest in guests) {
          final target = guest.localPlayerId == suspect ? impostor : suspect;
          unawaited(guest.vote(target == guest.localPlayerId ? host : target));
        }
        engine.vote(
          host,
          impostor == host ? guests[0].localPlayerId! : impostor,
        );
        async.flushMicrotasks();
        expect(guests[0].room!.phase, ImpostorPhase.reveal);
        expect(guests[0].room!.impostorId, impostor);

        async.elapse(ImpostorRoom.revealTime);
        if (impostor != host) {
          final guest = guests.firstWhere((g) => g.localPlayerId == impostor);
          expect(guest.room!.guessChoices, hasLength(6));
          unawaited(guest.guessWord(guest.room!.guessChoices.first));
        } else {
          engine.guessWord(host, engine.room!.guessChoices.first);
        }
        async.flushMicrotasks();
        expect(guests[1].room!.phase, ImpostorPhase.results);
        expect(guests[1].room!.word, engine.room!.word);

        // The host leaving closes the room for everyone.
        engine.close();
        async.flushMicrotasks();
        expect(guests[0].room, isNull);
        unawaited(impostorHost.stop());
        for (final guest in guests) {
          guest.dispose();
        }
      });
    });

    test('a guest who drops comes back as the same player', () async {
      final engine = engineWith(2);
      final server = MemoryServer();
      ImpostorHost(engine: engine, server: server).start();
      final guest = ImpostorClient(
        connect: server.connect,
        reconnectGap: const Duration(milliseconds: 10),
      );
      await guest.join(
        address: 'host',
        port: nearbyGamePort,
        roomCode: engine.room!.code,
        playerName: 'Riya',
        avatarIndex: 1,
      );
      await guest.setReady(true);
      await Future<void>.delayed(Duration.zero);
      engine.startGame(host);
      await Future<void>.delayed(Duration.zero);
      final id = guest.localPlayerId!;

      await server.guestLinks.single.close();
      await Future<void>.delayed(Duration.zero);
      expect(engine.room!.awayIds, contains(id));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.room!.awayIds, isNot(contains(id)));
      expect(guest.localPlayerId, id);
      expect(guest.room, isNotNull);
      guest.dispose();
      engine.dispose();
    });

    test('another game\'s phone is turned away', () {
      fakeAsync((async) {
        final engine = engineWith(0);
        final server = MemoryServer();
        ImpostorHost(engine: engine, server: server).start();
        late NearbyLink link;
        unawaited(server.connect('host', 1).then((value) => link = value));
        async.flushMicrotasks();
        final replies = <Map<String, Object?>>[];
        link.messages.listen(replies.add);
        link.send({
          't': 'join',
          'game': 'guess_the_drawing',
          'v': 1,
          'code': engine.room!.code,
        });
        async.flushMicrotasks();
        expect(replies.single['t'], 'refused');
      });
    });
  });
}
