import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_client.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

/// Short waits, so a whole game runs in moments.
const _fast = BotTiming(
  ready: (Duration(milliseconds: 1), Duration(milliseconds: 2)),
  hostStart: Duration(milliseconds: 1),
  pickLetter: Duration(milliseconds: 1),
  letterReveal: Duration(milliseconds: 5),
  voting: (Duration(milliseconds: 1), Duration(milliseconds: 2)),
  nextRound: (Duration(milliseconds: 1), Duration(milliseconds: 2)),
);

/// Lets messages travel between the phones.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// A host phone running a nearby room.
class _Host {
  _Host() {
    host.start();
  }

  final engine = LocalGameService(random: Random(1), timing: _fast);
  final server = MemoryServer();
  late final host = NearbyHost(engine: engine, server: server);

  Future<void> open({int rounds = 3, int size = 4, bool bots = false}) {
    return engine.createRoom(
      playerName: 'Sam',
      playerCount: size,
      mode: RoomMode.nearby,
      fillWithBots: bots,
      settings: GameSettings(rounds: rounds, answerSeconds: 30),
    );
  }

  Room get room => engine.room!;

  Future<NearbyClientService> join(
    String name, {
    String? code,
    Duration reconnectGap = const Duration(milliseconds: 10),
  }) async {
    final guest = NearbyClientService(
      connect: server.connect,
      reconnectGap: reconnectGap,
    );
    await guest.join(
      address: 'host',
      port: nearbyGamePort,
      roomCode: code ?? room.code,
      playerName: name,
      avatarIndex: 3,
    );
    await _settle();
    return guest;
  }

  Future<void> stop() async {
    await host.stop();
    engine.dispose();
  }
}

void main() {
  group('joining', () {
    test('a nearby room starts with just the host', () async {
      final host = _Host();
      await host.open();

      expect(host.room.mode, RoomMode.nearby);
      expect(host.room.players, hasLength(1));
      expect(host.room.players.single.isBot, isFalse);
      await host.stop();
    });

    test('a guest joins the lobby, and both phones see them', () async {
      final host = _Host();
      await host.open();

      final guest = await host.join('Luna');

      expect(host.room.players.map((p) => p.name), ['Sam', 'Luna']);
      expect(guest.room!.players.map((p) => p.name), ['Sam', 'Luna']);
      expect(guest.room!.mode, RoomMode.nearby);
      expect(guest.localPlayerId, host.room.players.last.id);
      await host.stop();
    });

    test('a full room turns friends away', () async {
      final host = _Host();
      await host.open(size: 2);
      await host.join('Luna');

      await expectLater(
        host.join('Kai'),
        throwsA(
          isA<JoinRefused>().having(
            (e) => e.message,
            'message',
            'That room '
                'is full.',
          ),
        ),
      );
      expect(host.room.players, hasLength(2));
      expect(host.room.emptySeats, 0);
      await host.stop();
    });

    test('with bots on, empty seats get bots when the game starts', () async {
      final host = _Host();
      await host.open(size: 5, bots: true);
      final guest = await host.join('Luna');
      expect(host.room.players, hasLength(2), reason: 'no bots in the lobby');

      await guest.setReady(true);
      await _settle();
      await host.engine.startRound();
      await _settle();

      final players = guest.room!.players;
      expect(players, hasLength(5));
      expect(players.where((p) => p.isBot), hasLength(3));
      expect(
        players.map((p) => p.name).toSet(),
        hasLength(5),
        reason: 'bots never share a name with anyone',
      );
      await host.stop();
    });

    test('with bots off, the game is just the friends who joined', () async {
      final host = _Host();
      await host.open(size: 5);
      final guest = await host.join('Luna');

      await guest.setReady(true);
      await _settle();
      await host.engine.startRound();
      await _settle();

      expect(guest.room!.players, hasLength(2));
      expect(guest.room!.players.any((p) => p.isBot), isFalse);
      await host.stop();
    });

    test('with bots on, the host can start alone', () async {
      final host = _Host();
      await host.open(size: 3, bots: true);
      expect(host.room.canStart, isTrue);

      await host.engine.startRound();

      expect(host.room.players, hasLength(3));
      expect(host.room.phase, GamePhase.letterSelection);
      await host.stop();
    });

    test('with bots off, the host cannot start alone', () async {
      final host = _Host();
      await host.open(size: 3);

      expect(host.room.canStart, isFalse);
      await host.stop();
    });

    test('a wrong code is refused', () async {
      final host = _Host();
      await host.open();

      await expectLater(
        host.join('Luna', code: 'ZZZZZZ'),
        throwsA(isA<JoinRefused>()),
      );
      expect(host.room.players, hasLength(1));
      await host.stop();
    });

    test('a game that has started cannot be joined', () async {
      final host = _Host();
      await host.open();
      final guest = await host.join('Luna');
      await guest.setReady(true);
      await _settle();
      await host.engine.startRound();

      await expectLater(host.join('Kai'), throwsA(isA<JoinRefused>()));
      await host.stop();
    });

    test('a guest whose phone drops out of the lobby leaves it', () async {
      final host = _Host();
      await host.open();
      await host.join('Luna');

      await host.server.guestLinks.single.close();
      await _settle();

      expect(host.room.players, hasLength(1));
      await host.stop();
    });

    test('a guest who leaves the lobby is taken out', () async {
      final host = _Host();
      await host.open();
      final guest = await host.join('Luna');

      await guest.leaveRoom();
      await _settle();

      expect(guest.room, isNull);
      expect(host.room.players, hasLength(1));
      await host.stop();
    });

    test('when the host leaves, guests go home', () async {
      final host = _Host();
      await host.open();
      final guest = await host.join('Luna');

      await host.engine.leaveRoom();
      await _settle();

      expect(guest.room, isNull);
      await host.stop();
    });
  });

  group('playing', () {
    /// Starts a round with Sam (host) and Luna (guest).
    Future<(_Host, NearbyClientService)> start({int rounds = 3}) async {
      final host = _Host();
      await host.open(rounds: rounds);
      final guest = await host.join('Luna');
      await guest.setReady(true);
      await _settle();
      await host.engine.startRound();
      await _settle();
      return (host, guest);
    }

    test('the guest sees the round begin', () async {
      final (host, guest) = await start();

      expect(guest.room!.phase, GamePhase.letterSelection);
      expect(guest.room!.round!.pickerId, host.engine.localPlayerId);
      await host.stop();
    });

    test('a whole round runs across both phones', () async {
      final (host, guest) = await start();

      await host.engine.selectLetter('M');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(guest.room!.phase, GamePhase.answering);
      expect(guest.room!.round!.deadline, isNotNull);

      await guest.updateAnswer(Category.animal, 'Monkey');
      await host.engine.updateAnswer(Category.animal, 'Mouse');
      await guest.submitAnswers();
      await host.engine.submitAnswers();
      await _settle();
      expect(guest.room!.phase, GamePhase.validating);

      // Each sees only the other's answer to vote on.
      expect(guest.room!.round!.ballot.map((i) => i.text), contains('Mouse'));
      expect(
        guest.room!.round!.ballot.map((i) => i.text),
        isNot(contains('Monkey')),
      );
      expect(
        host.engine.room!.round!.ballot.map((i) => i.text),
        contains('Monkey'),
      );

      for (final item in guest.room!.round!.ballot) {
        await guest.castVote(item.id, VoteChoice.valid);
      }
      for (final item in host.engine.room!.round!.ballot) {
        await host.engine.castVote(item.id, VoteChoice.valid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(guest.room!.phase, GamePhase.results);
      final results = guest.room!.round!.results!;
      expect(results.scores[guest.localPlayerId]!.answerPoints, 1000);
      await host.stop();
    });

    test('the guest picks the letter on their turn', () async {
      final (host, guest) = await start();
      await host.engine.selectLetter('M');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await guest.submitAnswers();
      await host.engine.submitAnswers();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await guest.nextRound();
      await host.engine.nextRound();
      await _settle();

      expect(guest.room!.round!.number, 2);
      expect(guest.room!.round!.pickerId, guest.localPlayerId);
      await guest.selectLetter('B');
      await _settle();

      expect(host.room.round!.letter, 'B');
      await host.stop();
    });

    test('a dropped connection rejoins as the same player', () async {
      final (host, guest) = await start();
      final id = guest.localPlayerId;

      await host.server.guestLinks.single.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(guest.room, isNotNull);
      expect(guest.localPlayerId, id);
      expect(host.server.guestLinks, hasLength(2));
      await host.engine.selectLetter('M');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(guest.room!.round!.letter, 'M');
      await host.stop();
    });

    /// Plays to voting, with the guest's answer for the host to vote on.
    Future<(_Host, NearbyClientService)> startVoting() async {
      final (host, guest) = await start();
      await host.engine.selectLetter('M');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await guest.updateAnswer(Category.animal, 'Monkey');
      await host.engine.updateAnswer(Category.animal, 'Mouse');
      await guest.submitAnswers();
      await host.engine.submitAnswers();
      await _settle();
      expect(guest.room!.phase, GamePhase.validating);
      return (host, guest);
    }

    test('voting has one timer, which both phones see', () async {
      final (host, guest) = await startVoting();

      final cards = guest.room!.round!.ballot.length;
      expect(guest.room!.round!.voteTime, GameRules.voteTimePerCard * cards);
      expect(guest.room!.round!.voteDeadline, isNotNull);
      await host.stop();
    });

    test('everyone sees who is still voting', () async {
      final (host, guest) = await startVoting();
      final guestId = guest.localPlayerId!;
      final hostId = host.engine.localPlayerId!;

      for (final item in host.engine.room!.round!.ballot) {
        await host.engine.castVote(item.id, VoteChoice.valid);
      }
      await _settle();
      expect(guest.room!.round!.votedPlayerIds, contains(hostId));
      expect(guest.room!.round!.votedPlayerIds, isNot(contains(guestId)));
      expect(host.room.phase, GamePhase.validating);

      for (final item in guest.room!.round!.ballot) {
        await guest.castVote(item.id, VoteChoice.valid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(host.room.phase, GamePhase.results);
      await host.stop();
    });

    test(
      'a vote shows at once, and gets through a dropped connection',
      () async {
        final (host, guest) = await startVoting();
        final guestId = guest.localPlayerId!;
        final item = guest.room!.round!.ballot.first;

        // The guest's phone loses the connection just as they vote.
        host.server.guestLinks.single.dropThisSide();
        await guest.castVote(item.id, VoteChoice.valid);

        expect(
          guest.room!.round!.myVotes[item.id],
          VoteChoice.valid,
          reason: 'the next answer shows without waiting for the host',
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(host.server.guestLinks, hasLength(2), reason: 'reconnected');
        expect(
          host.engine.roomFor(guestId)!.round!.myVotes[item.id],
          VoteChoice.valid,
        );
        await host.stop();
      },
    );

    test('a player back on a new connection is not marked away when the '
        'old one is noticed dying later', () async {
      final (host, guest) = await startVoting();
      final guestId = guest.localPlayerId!;
      final oldLink = host.server.guestLinks.single;

      // The guest's phone gives up first and rejoins...
      oldLink.dropThisSide();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(host.server.guestLinks, hasLength(2));
      // ...and only then does the host notice the old connection is dead.
      await oldLink.otherEnd.close();
      await _settle();

      for (final item in host.engine.room!.round!.ballot) {
        await host.engine.castVote(item.id, VoteChoice.valid);
      }
      await _settle();
      expect(
        host.room.phase,
        GamePhase.validating,
        reason: 'voting still waits for the guest, who is here',
      );
      expect(host.room.round!.votedPlayerIds, isNot(contains(guestId)));

      for (final item in guest.room!.round!.ballot) {
        await guest.castVote(item.id, VoteChoice.valid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(host.room.phase, GamePhase.results);
      await host.stop();
    });

    test('voting does not wait for a guest who has gone', () async {
      final (host, guest) = await start();
      await host.engine.selectLetter('M');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await guest.updateAnswer(Category.animal, 'Monkey');
      await guest.submitAnswers();
      await host.engine.submitAnswers();
      await _settle();

      // The guest leaves, and so never votes.
      await guest.leaveRoom();
      for (final item in host.engine.room!.round!.ballot) {
        await host.engine.castVote(item.id, VoteChoice.valid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(host.room.phase, GamePhase.results);
      await host.stop();
    });
  });
}
