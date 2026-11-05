import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/bot_player.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

const _timing = BotTiming();

/// Presses Next Round, then waits for the bots to press it too.
void _nextRound(FakeAsync time, LocalGameService service) {
  service.nextRound();
  time.elapse(_timing.nextRound.$2);
}

void _game(void Function(FakeAsync time, LocalGameService service) body) {
  fakeAsync((time) {
    final service = LocalGameService(random: Random(3));
    body(time, service);
    service.dispose();
    time.flushMicrotasks();
  });
}

/// A bot that gives the same answer in every category and always skips votes.
class _ScriptedBot extends BotPlayer {
  _ScriptedBot(this.answer) : super(random: Random(0));

  final String answer;

  @override
  Map<Category, String> answersFor(
    String letter, [
    Iterable<Category> categories = Category.values,
  ]) {
    return {for (final category in categories) category: answer};
  }

  @override
  bool? voteOn(Category category, String letter, String text) => null;
}

LocalGameService _scriptedGame(String botAnswer) {
  return LocalGameService(
    random: Random(3),
    createBot: (_) => _ScriptedBot(botAnswer),
  );
}

Room _room(LocalGameService service) => service.room!;

/// Plays one round as host, typing [typed], up to voting.
void _playToVoting(
  FakeAsync time,
  LocalGameService service, {
  int playerCount = 4,
  Map<Category, String> typed = const {},
}) {
  service.createRoom(playerName: 'Sam', playerCount: playerCount);
  time.elapse(const Duration(seconds: 4));
  service.startRound();
  service.selectLetter('M');
  time.elapse(_timing.letterReveal);
  typed.forEach(service.updateAnswer);
  time.elapse(GameRules.answerTime);
}

/// Answers every ballot item with [choice], then waits for the bots.
void _finishVoting(
  FakeAsync time,
  LocalGameService service, [
  VoteChoice choice = VoteChoice.skip,
]) {
  while (true) {
    final item = _room(service).round!.nextBallotItem;
    if (item == null) break;
    service.castVote(item.id, choice);
  }
  time.elapse(_timing.voting.$2);
}

void main() {
  group('the ballot', () {
    test('keeps answers hidden from the published room', () {
      _game((time, service) {
        _playToVoting(time, service);

        expect(_room(service).phase, GamePhase.validating);
        expect(_room(service).round!.answers, isEmpty);
        expect(_room(service).round!.results, isNull);
      });
    });

    test('leaves out the player\'s own answers', () {
      _game((time, service) {
        _playToVoting(time, service, typed: {Category.animal: 'Zzzmonkey'});

        final texts = _room(service).round!.ballot.map((item) => item.text);
        expect(texts, isNot(contains('Zzzmonkey')));
      });
    });

    test('leaves out wrong-letter answers, which need no vote', () {
      fakeAsync((time) {
        final service = _scriptedGame('Banana');

        _playToVoting(time, service);

        expect(_room(service).round!.ballot, isEmpty);
        service.dispose();
        time.flushMicrotasks();
      });
    });

    test('has one entry per identical answer', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 8);

        final ids = _room(service).round!.ballot.map((item) => item.id);
        expect(ids.toSet(), hasLength(ids.length));
      });
    });
  });

  group('voting', () {
    test('records each choice and moves to the next answer', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 8);
        final first = _room(service).round!.nextBallotItem!;

        service.castVote(first.id, VoteChoice.valid);

        final round = _room(service).round!;
        expect(round.myVotes[first.id], VoteChoice.valid);
        expect(round.nextBallotItem?.id, isNot(first.id));
      });
    });

    test('rejects a second vote on the same answer', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 8);
        final first = _room(service).round!.nextBallotItem!;
        service.castVote(first.id, VoteChoice.valid);

        expect(
          () => service.castVote(first.id, VoteChoice.invalid),
          throwsStateError,
        );
      });
    });

    test('stays in voting until the player finishes', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 8);

        time.elapse(const Duration(minutes: 5));

        expect(_room(service).phase, GamePhase.validating);
      });
    });

    test('moves to results once the bots have voted', () {
      _game((time, service) {
        _playToVoting(time, service);

        _finishVoting(time, service);

        expect(_room(service).phase, GamePhase.results);
        expect(_room(service).round!.results, isNotNull);
      });
    });

    test('moves on by itself when there is nothing to vote on', () {
      fakeAsync((time) {
        final service = _scriptedGame('');

        _playToVoting(time, service);
        expect(_room(service).round!.ballot, isEmpty);
        expect(_room(service).phase, GamePhase.validating);

        time.elapse(_timing.voting.$2);

        expect(_room(service).phase, GamePhase.results);
        service.dispose();
        time.flushMicrotasks();
      });
    });

    test('an answer shared by everyone scores with no vote', () {
      fakeAsync((time) {
        final service = _scriptedGame('Mango');

        _playToVoting(
          time,
          service,
          playerCount: 2,
          typed: {for (final category in Category.values) category: 'mango'},
        );
        expect(_room(service).round!.ballot, isEmpty);
        time.elapse(_timing.voting.$2);

        final score = _room(service).scores[service.localPlayerId]!;
        expect(score.answerPoints, 500 * Category.values.length);
        expect(score.validationPoints, 0);
        service.dispose();
        time.flushMicrotasks();
      });
    });
  });

  group('results', () {
    test('publish every player\'s answers and scores', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 3);
        _finishVoting(time, service);

        final room = _room(service);
        expect(room.round!.answers, hasLength(18));
        expect(
          room.round!.results!.lines.keys,
          unorderedEquals(room.playerIds),
        );
        expect(room.scores.keys, unorderedEquals(room.playerIds));
      });
    });

    test('a blank round scores nothing for the player', () {
      _game((time, service) {
        _playToVoting(time, service);
        _finishVoting(time, service);

        final line = _room(service).scores[service.localPlayerId]!;
        expect(line.answerPoints, 0);
      });
    });

    test('a wrong-letter answer earns nothing', () {
      _game((time, service) {
        _playToVoting(time, service, typed: {Category.food: 'Banana'});
        _finishVoting(time, service);

        final mine = _room(service)
            .round!
            .results!
            .lines[service.localPlayerId]!;
        final food = mine.firstWhere((line) => line.category == Category.food);
        expect(food.points, 0);
      });
    });
  });

  group('playing again', () {
    void playFullRound(FakeAsync time, LocalGameService service) {
      _finishVoting(time, service, VoteChoice.valid);
    }

    test('starts a new round with the next player picking', () {
      _game((time, service) {
        _playToVoting(time, service);
        playFullRound(time, service);
        final firstPicker = _room(service).round!.pickerId;

        _nextRound(time, service);

        final room = _room(service);
        expect(room.phase, GamePhase.letterSelection);
        expect(room.round!.number, 2);
        expect(room.round!.pickerId, isNot(firstPicker));
        expect(room.round!.pickerId, room.players[1].id);
      });
    });

    test('remembers used letters', () {
      _game((time, service) {
        _playToVoting(time, service);
        playFullRound(time, service);

        _nextRound(time, service);

        expect(_room(service).usedLetters, {'M'});
      });
    });

    test('a bot picker never repeats a letter', () {
      _game((time, service) {
        _playToVoting(time, service);
        playFullRound(time, service);

        _nextRound(time, service);
        time.elapse(_timing.pickLetter);

        expect(_room(service).round!.letter, isNot('M'));
        expect(_room(service).usedLetters, hasLength(2));
      });
    });

    test('the picker rotates back to the first player', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 2);
        playFullRound(time, service);

        _nextRound(time, service);
        time.elapse(_timing.pickLetter + _timing.letterReveal);
        time.elapse(GameRules.answerTime);
        playFullRound(time, service);
        _nextRound(time, service);

        expect(_room(service).round!.pickerId, service.localPlayerId);
      });
    });

    test('keeps a running total across rounds', () {
      _game((time, service) {
        _playToVoting(time, service, playerCount: 3);
        playFullRound(time, service);
        final firstTotals = _room(service).scores;
        final botId = _room(service).players[1].id;
        final firstRound = _room(service).round!.results!.scores[botId]!;
        expect(firstTotals[botId]!.total, firstRound.total);

        _nextRound(time, service);
        time.elapse(_timing.pickLetter + _timing.letterReveal);
        time.elapse(GameRules.answerTime);
        playFullRound(time, service);

        final secondRound = _room(service).round!.results!.scores[botId]!;
        expect(
          _room(service).scores[botId]!.total,
          firstRound.total + secondRound.total,
        );
      });
    });

    test('clears the previous round\'s answers', () {
      _game((time, service) {
        _playToVoting(time, service);
        playFullRound(time, service);

        _nextRound(time, service);

        final round = _room(service).round!;
        expect(round.answers, isEmpty);
        expect(round.results, isNull);
        expect(round.letter, isNull);
      });
    });

    test('only works from the results', () {
      _game((time, service) {
        _playToVoting(time, service);

        expect(service.nextRound, throwsStateError);
      });
    });
  });

  test('leaving clears the room and the scores', () {
    _game((time, service) {
      _playToVoting(time, service);
      _finishVoting(time, service);

      service.leaveRoom();
      expect(service.room, isNull);

      service.createRoom(playerName: 'Sam', playerCount: 2);
      expect(_room(service).scores, isEmpty);
      expect(_room(service).usedLetters, isEmpty);
    });
  });
}
