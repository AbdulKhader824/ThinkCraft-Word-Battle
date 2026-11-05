import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

const _timing = BotTiming();

/// Presses Next Round, then waits for the bots to press it too.
void _nextRound(FakeAsync time, LocalGameService service) {
  service.nextRound();
  time.elapse(_timing.nextRound.$2);
}

const _twoCategories = [Category.animal, Category.food];

void _game(void Function(FakeAsync time, LocalGameService service) body) {
  fakeAsync((time) {
    final service = LocalGameService(random: Random(5));
    body(time, service);
    service.dispose();
    time.flushMicrotasks();
  });
}

Room _room(LocalGameService service) => service.room!;

void _create(
  FakeAsync time,
  LocalGameService service, {
  int rounds = 3,
  int answerSeconds = 90,
  List<Category> categories = Category.values,
  int playerCount = 3,
}) {
  service.createRoom(
    playerName: 'Sam',
    playerCount: playerCount,
    settings: GameSettings(
      rounds: rounds,
      answerSeconds: answerSeconds,
      categories: categories,
    ),
  );
  time.elapse(const Duration(seconds: 4));
  service.startRound();
}

/// Plays the current round from letter selection to results.
void _playRound(FakeAsync time, LocalGameService service) {
  final room = _room(service);
  if (room.round!.pickerId == service.localPlayerId) {
    final unused = GameRules.letters.firstWhere(
      (letter) => !room.usedLetters.contains(letter),
    );
    service.selectLetter(unused);
  } else {
    time.elapse(_timing.pickLetter);
  }
  time.elapse(_timing.letterReveal);
  time.elapse(GameRules.answerTime);

  while (true) {
    final item = _room(service).round!.nextBallotItem;
    if (item == null) break;
    service.castVote(item.id, VoteChoice.valid);
  }
  time.elapse(_timing.voting.$2);
}

void main() {
  group('chosen settings', () {
    test('the room keeps the host\'s settings', () {
      _game((time, service) {
        _create(time, service, rounds: 5, categories: _twoCategories);

        expect(_room(service).settings.rounds, 5);
        expect(_room(service).settings.categories, _twoCategories);
      });
    });

    test('a room created without settings uses the standard game', () {
      _game((time, service) {
        service.createRoom(playerName: 'Sam', playerCount: 2);

        expect(_room(service).settings.rounds, 3);
        expect(_room(service).settings.usesEveryCategory, isTrue);
      });
    });

    test('a joined room uses the standard game', () {
      _game((time, service) {
        service.joinRoom(playerName: 'Sam', roomCode: 'ABC234');

        expect(_room(service).settings.rounds, 3);
        expect(_room(service).settings.usesEveryCategory, isTrue);
      });
    });

    test('answers only cover the chosen categories', () {
      _game((time, service) {
        _create(time, service, categories: _twoCategories);
        _playRound(time, service);

        final answers = _room(service).round!.answers;
        expect(answers, hasLength(3 * _twoCategories.length));
        expect(
          answers.map((answer) => answer.category).toSet(),
          _twoCategories.toSet(),
        );
      });
    });

    test('the ballot only has the chosen categories', () {
      _game((time, service) {
        _create(time, service, categories: const [Category.movie]);
        service.selectLetter('M');
        time.elapse(_timing.letterReveal);
        time.elapse(GameRules.answerTime);

        for (final item in _room(service).round!.ballot) {
          expect(item.category, Category.movie);
        }
      });
    });

    test('results only list the chosen categories', () {
      _game((time, service) {
        _create(time, service, categories: _twoCategories);
        _playRound(time, service);

        final lines = _room(service).round!.results!.lines;
        for (final playerLines in lines.values) {
          expect(playerLines.map((line) => line.category), _twoCategories);
        }
      });
    });
  });

  group('the answer timer', () {
    void toAnswering(
      FakeAsync time,
      LocalGameService service, {
      required int seconds,
    }) {
      _create(time, service, answerSeconds: seconds);
      service.selectLetter('M');
      time.elapse(_timing.letterReveal);
    }

    for (final seconds in GameSettings.answerSecondsOptions) {
      test('a $seconds-second room sets a $seconds-second deadline', () {
        _game((time, service) {
          toAnswering(time, service, seconds: seconds);

          final deadline = _room(service).round!.deadline!;
          expect(deadline.difference(clock.now()), Duration(seconds: seconds));
        });
      });
    }

    test('a 30-second round ends at 30 seconds, and not before', () {
      _game((time, service) {
        toAnswering(time, service, seconds: 30);

        time.elapse(const Duration(seconds: 29));
        expect(_room(service).phase, GamePhase.answering);

        time.elapse(const Duration(seconds: 1));
        expect(_room(service).phase, isNot(GamePhase.answering));
      });
    });

    test('bots speed up to answer within a 30-second round', () {
      _game((time, service) {
        toAnswering(time, service, seconds: 30);

        // Bots take 25-80 seconds in a 90-second round, so a third of that.
        time.elapse(const Duration(milliseconds: 26700));

        final round = _room(service).round!;
        expect(round.submittedPlayerIds, hasLength(2));
        expect(_room(service).phase, GamePhase.answering);
      });
    });

    test('bots keep their normal speed in a 90-second round', () {
      _game((time, service) {
        toAnswering(time, service, seconds: 90);

        time.elapse(const Duration(seconds: 24));

        expect(_room(service).round!.submittedPlayerIds, isEmpty);
      });
    });

    test('a new game keeps the chosen timer', () {
      _game((time, service) {
        service.createRoom(
          playerName: 'Sam',
          playerCount: 2,
          settings: GameSettings(rounds: 1, answerSeconds: 60),
        );
        time.elapse(const Duration(seconds: 4));
        service.startRound();
        _playRound(time, service);

        service.newGame();
        service.selectLetter('Q');
        time.elapse(_timing.letterReveal);

        final deadline = _room(service).round!.deadline!;
        expect(deadline.difference(clock.now()), const Duration(seconds: 60));
      });
    });
  });

  group('the number of rounds', () {
    test('the last round is marked as final', () {
      _game((time, service) {
        _create(time, service, rounds: 3);
        expect(_room(service).isFinalRound, isFalse);

        _playRound(time, service);
        _nextRound(time, service);
        _playRound(time, service);
        expect(_room(service).isFinalRound, isFalse);

        _nextRound(time, service);
        _playRound(time, service);
        expect(_room(service).round!.number, 3);
        expect(_room(service).isFinalRound, isTrue);
      });
    });

    test('a 1-round game is final straight away', () {
      _game((time, service) {
        _create(time, service, rounds: 1);
        _playRound(time, service);

        expect(_room(service).isFinalRound, isTrue);
      });
    });

    test('there is no next round after the final one', () {
      _game((time, service) {
        _create(time, service, rounds: 1);
        _playRound(time, service);

        expect(service.nextRound, throwsStateError);
        expect(_room(service).phase, GamePhase.results);
      });
    });

    test('a 10-round game never repeats a letter', () {
      _game((time, service) {
        _create(time, service, rounds: 10, playerCount: 2);

        final letters = <String>[];
        for (var round = 1; round <= 10; round++) {
          _playRound(time, service);
          letters.add(_room(service).round!.letter!);
          if (round < 10) _nextRound(time, service);
        }

        expect(letters.toSet(), hasLength(10));
        expect(_room(service).isFinalRound, isTrue);
      });
    });
  });

  group('a new game', () {
    test('starts again at round 1 with the host picking', () {
      _game((time, service) {
        _create(time, service, rounds: 1);
        _playRound(time, service);

        service.newGame();

        final room = _room(service);
        expect(room.phase, GamePhase.letterSelection);
        expect(room.round!.number, 1);
        expect(room.round!.pickerId, room.host.id);
      });
    });

    test('clears the scores and letters', () {
      _game((time, service) {
        _create(time, service, rounds: 1);
        _playRound(time, service);
        expect(_room(service).usedLetters, isNotEmpty);

        service.newGame();

        expect(_room(service).scores, isEmpty);
        expect(_room(service).usedLetters, isEmpty);
      });
    });

    test('keeps the room, players and settings', () {
      _game((time, service) {
        _create(time, service, rounds: 1, categories: _twoCategories);
        _playRound(time, service);
        final before = _room(service);

        service.newGame();

        final after = _room(service);
        expect(after.code, before.code);
        expect(after.playerIds, before.playerIds);
        expect(after.settings.rounds, 1);
        expect(after.settings.categories, _twoCategories);
      });
    });

    test('only works from the results', () {
      _game((time, service) {
        _create(time, service);

        expect(service.newGame, throwsStateError);
      });
    });
  });
}
