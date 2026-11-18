import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/most_likely_room.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_client.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_codec.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_engine.dart';
import 'package:thinkcraft_word_battle/services/most_likely/most_likely_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

const host = MostLikelyEngine.hostId;

/// A host engine with [guests] players joined and ready.
MostLikelyEngine engineWith(
  int guests, {
  MostLikelySettings? settings,
  int seed = 2,
}) {
  final engine = MostLikelyEngine(random: Random(seed))
    ..createRoom(
      hostName: 'Sam',
      avatarIndex: 0,
      capacity: 8,
      settings: settings ?? MostLikelySettings(),
    );
  for (var number = 1; number <= guests; number++) {
    final id = engine.addPlayer(name: 'P$number', avatarIndex: number);
    engine.setReady(id, true);
  }
  return engine;
}

/// Everyone votes for [target], then the reveal's time runs out.
void everyoneVotes(MostLikelyEngine engine, String target, FakeAsync async) {
  for (final player in engine.room!.players) {
    engine.vote(player.id, target);
  }
  async.elapse(MostLikelyRoom.revealTime);
}

void main() {
  group('engine', () {
    test('the lobby needs three ready players', () {
      final engine = engineWith(1);
      expect(engine.room!.canStart, isFalse);
      engine.startGame(host);
      expect(engine.room!.phase, MostLikelyPhase.lobby);
      final riya = engine.addPlayer(name: 'Riya', avatarIndex: 2);
      engine.setReady(riya, true);
      expect(engine.room!.canStart, isTrue);
    });

    test('a full room or a started game turns players away', () {
      final engine = MostLikelyEngine()
        ..createRoom(
          hostName: 'Sam',
          avatarIndex: 0,
          capacity: 3,
          settings: MostLikelySettings(),
        );
      final a = engine.addPlayer(name: 'A', avatarIndex: 1);
      final b = engine.addPlayer(name: 'B', avatarIndex: 2);
      expect(
        () => engine.addPlayer(name: 'C', avatarIndex: 3),
        throwsA(isA<JoinRefused>()),
      );
      engine
        ..setReady(a, true)
        ..setReady(b, true)
        ..startGame(host);
      engine.removePlayer(b);
      // Fewer than three players left closes the room.
      expect(engine.room, isNull);
    });

    test('votes stay secret, and only counts are shown', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        final room = engine.room!;
        expect(room.phase, MostLikelyPhase.vote);
        expect(room.questionNumber, 1);
        expect(room.questionText, startsWith('Who is most likely to '));

        engine
          ..vote(host, 'guest-1')
          ..vote('guest-1', 'guest-1') // Voting for yourself is fine.
          ..vote('guest-2', host);
        // A vote can't be changed.
        engine.vote(host, 'guest-2');
        expect(engine.room!.votes[host], 'guest-1');

        final mine = engine.roomFor('guest-2')!;
        expect(mine.votes, {'guest-2': host});
        expect(mine.votedIds, {host, 'guest-1', 'guest-2'});

        engine.vote('guest-3', 'guest-1');
        // Everyone voted: the reveal comes at once.
        final reveal = engine.roomFor('guest-2')!;
        expect(reveal.phase, MostLikelyPhase.reveal);
        expect(reveal.voteCounts, {'guest-1': 3, host: 1});
        expect(reveal.mostLikelyIds, {'guest-1'});
        // Still nobody sees who voted for whom, nor others' points.
        expect(reveal.votes, {'guest-2': host});
        expect(reveal.questionPoints, {'guest-2': 0});
        expect(engine.roomFor(host)!.questionPoints, {host: 1});
        expect(reveal.titles, {
          'guest-1': [room.question],
        });
      });
    });

    test('time running out reveals the votes so far', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        engine.vote(host, 'guest-1');
        async.elapse(MostLikelyRoom.voteTime);
        final room = engine.room!;
        expect(room.phase, MostLikelyPhase.reveal);
        expect(room.mostLikelyIds, {'guest-1'});
        expect(room.questionPoints, {host: 1});
      });
    });

    test('nobody voting means nobody is most likely', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        async.elapse(MostLikelyRoom.voteTime);
        expect(engine.room!.mostLikelyIds, isEmpty);
        expect(engine.room!.titles, isEmpty);
      });
    });

    test('five questions, then the leaderboard with Next Round', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        for (var number = 1; number <= 5; number++) {
          expect(engine.room!.questionNumber, number);
          expect(engine.room!.phase, MostLikelyPhase.vote);
          // The host reads the room every time; guest-2 never does.
          engine
            ..vote(host, 'guest-1')
            ..vote('guest-1', 'guest-1')
            ..vote('guest-2', host);
          async.elapse(MostLikelyRoom.revealTime);
        }
        final results = engine.roomFor('guest-2')!;
        expect(results.phase, MostLikelyPhase.results);
        expect(results.isGameOver, isFalse);
        expect(results.scores, {host: 5, 'guest-1': 5, 'guest-2': 0});
        expect(results.roundPoints, {host: 5, 'guest-1': 5, 'guest-2': 0});
        expect(results.titles['guest-1'], hasLength(5));

        for (final id in [host, 'guest-1', 'guest-2']) {
          engine.nextRound(id);
        }
        final next = engine.room!;
        expect(next.phase, MostLikelyPhase.vote);
        expect(next.questionNumber, 6);
        expect(next.roundPoints, isEmpty);
        expect(next.scores, {host: 5, 'guest-1': 5, 'guest-2': 0});
      });
    });

    test('questions never repeat in a game', () {
      fakeAsync((async) {
        final engine = engineWith(
          2,
          settings: MostLikelySettings(questions: 20),
        )..startGame(host);
        final asked = <String>{};
        while (!engine.room!.isGameOver) {
          final room = engine.room!;
          if (room.phase == MostLikelyPhase.results) {
            for (final player in room.players) {
              engine.nextRound(player.id);
            }
            continue;
          }
          expect(asked.add(room.question!), isTrue);
          everyoneVotes(engine, host, async);
        }
        expect(asked, hasLength(20));
        final end = engine.room!;
        expect(end.scores[host], 20);
        expect(end.deadline, isNull);

        engine.newGame(host);
        expect(engine.room!.questionNumber, 1);
        expect(engine.room!.scores, isEmpty);
        expect(engine.room!.titles, isEmpty);
      });
    });

    test("an away player doesn't hold up the vote", () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        engine
          ..vote(host, 'guest-1')
          ..vote('guest-1', host)
          ..vote('guest-2', host);
        expect(engine.room!.phase, MostLikelyPhase.vote);
        engine.setAway('guest-3', away: true);
        expect(engine.room!.phase, MostLikelyPhase.reveal);
      });
    });

    test('votes for a player who left are dropped', () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        engine
          ..vote(host, 'guest-3')
          ..vote('guest-1', 'guest-3')
          ..vote('guest-2', host);
        engine.removePlayer('guest-3');
        final room = engine.room!;
        expect(room.phase, MostLikelyPhase.reveal);
        expect(room.voteCounts, {host: 1});
        expect(room.mostLikelyIds, {host});
      });
    });

    test("players who don't press Next Round in time leave", () {
      fakeAsync((async) {
        final engine = engineWith(3)..startGame(host);
        for (var number = 1; number <= 5; number++) {
          everyoneVotes(engine, 'guest-1', async);
        }
        engine
          ..nextRound(host)
          ..nextRound('guest-1')
          ..nextRound('guest-2');
        expect(engine.room!.phase, MostLikelyPhase.results);
        async.elapse(MostLikelyRoom.nextRoundWait);
        final room = engine.room!;
        expect(room.phase, MostLikelyPhase.vote);
        expect(room.players.map((p) => p.id), [host, 'guest-1', 'guest-2']);
        expect(room.scores.keys, isNot(contains('guest-3')));
      });
    });

    test('rooms travel as JSON', () {
      fakeAsync((async) {
        final engine = engineWith(2)..startGame(host);
        everyoneVotes(engine, 'guest-1', async);
        engine.vote('guest-2', host);
        final view = engine.roomFor('guest-2')!;
        final back = MostLikelyCodec.decode(MostLikelyCodec.encode(view));
        expect(back.phase, MostLikelyPhase.vote);
        expect(back.questionNumber, 2);
        expect(back.question, view.question);
        expect(back.topic, view.topic);
        expect(back.votes, view.votes);
        expect(back.votedIds, view.votedIds);
        expect(back.roundPoints, view.roundPoints);
        expect(back.titles, view.titles);
        expect(back.settings.questions, view.settings.questions);
        expect(back.settings.topics, view.settings.topics);
        expect(back.players.map((p) => p.name), ['Sam', 'P1', 'P2']);
        expect(
          back.deadline!.difference(view.deadline!).inSeconds.abs(),
          lessThan(2),
        );
      });
    });
  });

  group('nearby', () {
    test('guests join, vote and see the result', () {
      fakeAsync((async) {
        final engine = MostLikelyEngine(random: Random(4))
          ..createRoom(
            hostName: 'Sam',
            avatarIndex: 0,
            capacity: 4,
            settings: MostLikelySettings(),
          );
        final server = MemoryServer();
        final mostLikelyHost = MostLikelyHost(engine: engine, server: server)
          ..start();
        final guests = <MostLikelyClient>[];
        for (final name in ['Riya', 'Ali']) {
          final guest = MostLikelyClient(connect: server.connect);
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
        final riya = guests[0].localPlayerId!;
        expect(guests[1].room!.phase, MostLikelyPhase.vote);
        expect(guests[1].room!.question, engine.room!.question);

        unawaited(guests[0].vote(riya));
        unawaited(guests[1].vote(riya));
        async.flushMicrotasks();
        expect(guests[1].room!.votedIds, {riya, guests[1].localPlayerId});
        expect(guests[1].room!.votes, {guests[1].localPlayerId: riya});

        engine.vote(host, host);
        async.flushMicrotasks();
        final seen = guests[1].room!;
        expect(seen.phase, MostLikelyPhase.reveal);
        expect(seen.voteCounts, {riya: 2, host: 1});
        expect(seen.mostLikelyIds, {riya});
        expect(seen.questionPoints, {guests[1].localPlayerId: 1});

        // The host leaving closes the room for everyone.
        engine.close();
        async.flushMicrotasks();
        expect(guests[0].room, isNull);
        unawaited(mostLikelyHost.stop());
        for (final guest in guests) {
          guest.dispose();
        }
      });
    });

    test('a guest who drops comes back as the same player', () async {
      final engine = engineWith(2);
      final server = MemoryServer();
      MostLikelyHost(engine: engine, server: server).start();
      final guest = MostLikelyClient(
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

    test("another game's phone is turned away", () {
      fakeAsync((async) {
        final engine = engineWith(0);
        final server = MemoryServer();
        MostLikelyHost(engine: engine, server: server).start();
        late NearbyLink link;
        unawaited(server.connect('host', 1).then((value) => link = value));
        async.flushMicrotasks();
        final replies = <Map<String, Object?>>[];
        link.messages.listen(replies.add);
        link.send({
          't': 'join',
          'game': 'the_impostor',
          'v': 1,
          'code': engine.room!.code,
        });
        async.flushMicrotasks();
        expect(replies.single['t'], 'refused');
      });
    });
  });
}
