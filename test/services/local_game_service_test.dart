import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/room_input_rules.dart';

const _timing = BotTiming();
const _lobbyTime = Duration(seconds: 4);
final _revealTime = _timing.letterReveal;

/// Runs [body] with fake time, so the 90-second timer takes no real time.
void _game(void Function(FakeAsync time, LocalGameService service) body) {
  fakeAsync((time) {
    final service = LocalGameService(random: Random(1));
    body(time, service);
    service.dispose();
    time.flushMicrotasks();
  });
}

Room _room(LocalGameService service) => service.room!;

/// Creates a room as host and plays up to the answering phase.
void _playToAnswering(
  FakeAsync time,
  LocalGameService service, {
  int playerCount = 4,
  String letter = 'M',
}) {
  service.createRoom(playerName: 'Sam', playerCount: playerCount);
  time.elapse(_lobbyTime);
  service.startRound();
  service.selectLetter(letter);
  time.elapse(_revealTime);
}

void main() {
  group('creating a room', () {
    test('makes the player the ready host, with bots filling the room', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 5);

        final room = _room(service);
        expect(room.players, hasLength(5));
        expect(room.host.id, service.localPlayerId);
        expect(room.host.name, 'Sam');
        expect(room.host.isReady, isTrue);
        expect(room.players.where((p) => p.isBot), hasLength(4));
        expect(room.phase, GamePhase.lobby);
      });
    });

    test('generates a valid room code', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 2);
        expect(RoomInputRules.validateRoomCode(_room(service).code), isNull);
      });
    });

    test('supports 2 to 8 players, with unique names and avatars', () {
      for (var count = 2; count <= 8; count++) {
        _game((time, service) {
          service.createRoom(playerName: 'Luna', playerCount: count);

          final players = _room(service).players;
          expect(players, hasLength(count));
          expect(
            players.map((p) => p.name.toLowerCase()).toSet(),
            hasLength(count),
          );
          expect(players.map((p) => p.avatarIndex).toSet(), hasLength(count));
        });
      }
    });

    test('bots become ready over time', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 4);
        expect(_room(service).canStart, isFalse);

        time.elapse(_lobbyTime);
        expect(_room(service).canStart, isTrue);
      });
    });
  });

  group('joining a room', () {
    test('keeps the code, and a bot is the host', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');

        final room = _room(service);
        expect(room.code, 'ABC234');
        expect(room.host.isBot, isTrue);
        expect(room.playerById(service.localPlayerId!).isReady, isFalse);
      });
    });

    test('the bot host waits until the player is ready, then starts', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');
        time.elapse(const Duration(seconds: 30));
        expect(_room(service).phase, GamePhase.lobby);

        service.setReady(true);
        time.elapse(_timing.hostStart);
        expect(_room(service).phase, GamePhase.letterSelection);
      });
    });

    test('the bot host does not start if the player un-readies', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');
        time.elapse(_lobbyTime);

        service.setReady(true);
        time.elapse(const Duration(milliseconds: 100));
        service.setReady(false);
        time.elapse(const Duration(seconds: 10));

        expect(_room(service).phase, GamePhase.lobby);
      });
    });

    test('a bot picks the letter, and everyone gets it', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');
        time.elapse(_lobbyTime);
        service.setReady(true);
        time.elapse(_timing.hostStart + _timing.pickLetter);

        final round = _room(service).round!;
        expect(round.pickerId, _room(service).host.id);
        expect(GameRules.letters, contains(round.letter));
      });
    });
  });

  group('starting a round', () {
    test('the host cannot start until everyone is ready', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 4);

        expect(service.startRound, throwsStateError);
        expect(_room(service).phase, GamePhase.lobby);
      });
    });

    test('only the host can start', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');
        time.elapse(_lobbyTime);

        expect(service.startRound, throwsStateError);
      });
    });

    test('hosts cannot change their ready status', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 4);
        expect(() => service.setReady(false), throwsStateError);
      });
    });

    test('the host picks the first letter', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 2);
        time.elapse(_lobbyTime);
        service.startRound();

        expect(_room(service).phase, GamePhase.letterSelection);
        expect(_room(service).round!.pickerId, service.localPlayerId);
      });
    });
  });

  group('selecting a letter', () {
    void toLetterSelection(FakeAsync time, LocalGameService service) {
      service.createRoom(playerName: 'Sam', playerCount: 2);
      time.elapse(_lobbyTime);
      service.startRound();
    }

    test('sets the letter, then starts answering after the reveal', () {
      _game((time, service) {
        toLetterSelection(time, service);

        service.selectLetter('M');
        expect(_room(service).round!.letter, 'M');
        expect(_room(service).usedLetters, {'M'});
        expect(_room(service).phase, GamePhase.letterSelection);

        time.elapse(_revealTime);
        expect(_room(service).phase, GamePhase.answering);
      });
    });

    test('cannot be changed once chosen', () {
      _game((time, service) {
        toLetterSelection(time, service);
        service.selectLetter('M');

        expect(() => service.selectLetter('A'), throwsStateError);
      });
    });

    test('rejects anything that is not a capital letter', () {
      _game((time, service) {
        toLetterSelection(time, service);

        expect(() => service.selectLetter('7'), throwsArgumentError);
      });
    });
  });

  group('the answer timer', () {
    test('counts from a deadline 90 seconds after answering starts', () {
      _game((time, service) {
        _playToAnswering(time, service);

        expect(
          _room(service).round!.deadline!.difference(clock.now()),
          GameRules.answerTime,
        );
      });
    });

    test('keeps the same deadline as time passes', () {
      _game((time, service) {
        _playToAnswering(time, service);
        final deadline = _room(service).round!.deadline;

        time.elapse(const Duration(seconds: 30));

        expect(_room(service).round!.deadline, deadline);
        expect(deadline!.difference(clock.now()), const Duration(seconds: 60));
      });
    });

    test('moves on at 90 seconds, and not before', () {
      _game((time, service) {
        _playToAnswering(time, service);

        time.elapse(const Duration(seconds: 89));
        expect(_room(service).phase, GamePhase.answering);

        time.elapse(const Duration(seconds: 1));
        expect(_room(service).phase, GamePhase.validating);
      });
    });

    test('locks whatever was typed when time runs out', () {
      _game((time, service) {
        _playToAnswering(time, service);
        service.updateAnswer(Category.animal, '  Monkey ');
        service.updateAnswer(Category.food, 'Man');

        time.elapse(GameRules.answerTime);

        final mine = _room(service).round!.answers
            .where((answer) => answer.playerId == service.localPlayerId);
        expect(mine, hasLength(6));
        expect(
          mine.firstWhere((a) => a.category == Category.animal).text,
          'Monkey',
        );
        expect(mine.firstWhere((a) => a.category == Category.food).text, 'Man');
        expect(
          mine.where((answer) => answer.isEmpty),
          hasLength(4),
          reason: 'untouched fields count as empty',
        );
      });
    });

    test('expires after the app was frozen in the background', () {
      var now = DateTime(2026, 1, 1, 12);

      fakeAsync((time) {
        // Set inside fakeAsync, which otherwise supplies its own clock.
        withClock(Clock(() => now), () {
          final service = LocalGameService(random: Random(1));
          _playToAnswering(time, service);

          // The clock moves on, but Android has paused the app, so no timer
          // has had a chance to fire.
          now = now.add(const Duration(seconds: 89));
          service.refresh();
          expect(service.room!.phase, GamePhase.answering);

          now = now.add(const Duration(seconds: 2));
          service.refresh();
          expect(service.room!.phase, GamePhase.validating);

          service.dispose();
          time.flushMicrotasks();
        });
      });
    });
  });

  group('submitting answers', () {
    test('locks the answers and waits for the others', () {
      _game((time, service) {
        _playToAnswering(time, service);
        service.updateAnswer(Category.animal, 'Monkey');

        service.submitAnswers();

        final round = _room(service).round!;
        expect(round.submittedPlayerIds, contains(service.localPlayerId));
        expect(_room(service).phase, GamePhase.answering);
      });
    });

    test('ignores typing after the answers are locked', () {
      _game((time, service) {
        _playToAnswering(time, service, playerCount: 2);
        service.updateAnswer(Category.animal, 'Monkey');
        service.submitAnswers();
        service.updateAnswer(Category.animal, 'Changed');

        time.elapse(_timing.afterHumanSubmit.$2);

        final answer = _room(service).round!.answers.firstWhere(
          (a) =>
              a.playerId == service.localPlayerId &&
              a.category == Category.animal,
        );
        expect(answer.text, 'Monkey');
      });
    });

    test('submitting twice changes nothing', () {
      _game((time, service) {
        _playToAnswering(time, service);
        service.submitAnswers();
        final submitted = _room(service).round!.submittedPlayerIds;

        service.submitAnswers();

        expect(_room(service).round!.submittedPlayerIds, submitted);
      });
    });

    test('bots finish soon after the player submits', () {
      _game((time, service) {
        _playToAnswering(time, service, playerCount: 8);

        service.submitAnswers();
        time.elapse(_timing.afterHumanSubmit.$2);

        expect(_room(service).phase, GamePhase.validating);
      });
    });

    test('bots submit by themselves over time', () {
      _game((time, service) {
        _playToAnswering(time, service);

        time.elapse(_timing.answer.$2);

        final round = _room(service).round!;
        expect(round.submittedPlayerIds, hasLength(3));
        expect(
          round.submittedPlayerIds,
          isNot(contains(service.localPlayerId)),
        );
      });
    });

    test('hides answers until everyone has locked in', () {
      _game((time, service) {
        _playToAnswering(time, service);
        time.elapse(_timing.answer.$2);

        expect(_room(service).round!.answers, isEmpty);
      });
    });

    test('collects six answers per player afterwards', () {
      _game((time, service) {
        _playToAnswering(time, service, playerCount: 3);
        time.elapse(GameRules.answerTime);

        expect(_room(service).round!.answers, hasLength(18));
      });
    });

    test('announces every change on the stream', () {
      _game((time, service) {
        final phases = <GamePhase?>[];
        final subscription = service.roomChanges.listen(
          (room) => phases.add(room?.phase),
        );

        _playToAnswering(time, service, playerCount: 2);
        time.elapse(GameRules.answerTime);
        subscription.cancel();

        expect(phases.toSet(), {
          GamePhase.lobby,
          GamePhase.letterSelection,
          GamePhase.answering,
          GamePhase.validating,
        });
      });
    });
  });

  group('leaving', () {
    test('clears the room and stops every bot', () {
      _game((time, service) {
        _playToAnswering(time, service);

        service.leaveRoom();
        time.elapse(const Duration(minutes: 5));

        expect(service.room, isNull);
        expect(service.localPlayerId, isNull);
      });
    });
  });
}
