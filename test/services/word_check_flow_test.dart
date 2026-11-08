import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/bot_player.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/word_check.dart';

const _timing = BotTiming();

/// A bot that answers "Monkey" everywhere and always skips votes.
class _MonkeyBot extends BotPlayer {
  _MonkeyBot() : super(random: Random(0));

  @override
  Map<Category, String> answersFor(
    String letter, [
    Iterable<Category> categories = Category.values,
  ]) => {for (final category in categories) category: 'Monkey'};

  @override
  bool? voteOn(Category category, String letter, String text) => null;
}

final _words = SetWordList({
  Category.animal: ['Monkey'],
  Category.food: ['Mango'],
});

/// Plays a 3-player practice round up to voting. The player answers Mango
/// (listed) for food and Moose (not listed) for animal; the bots answer
/// Monkey everywhere, which is only listed as an animal.
LocalGameService _playToVoting(
  FakeAsync time,
  AnswerCheck check, {
  WordList? words,
}) {
  final service = LocalGameService(
    random: Random(3),
    createBot: (_) => _MonkeyBot(),
    wordList: words ?? _words,
  );
  service.createRoom(
    playerName: 'Sam',
    playerCount: 3,
    settings: GameSettings(answerCheck: check),
  );
  time.elapse(const Duration(seconds: 4));
  service.startRound();
  service.selectLetter('M');
  time.elapse(_timing.letterReveal);
  service.updateAnswer(Category.food, 'Mango');
  service.updateAnswer(Category.animal, 'Moose');
  time.elapse(GameRules.answerTime);
  expect(service.room!.phase, GamePhase.validating);
  return service;
}

void _finishVoting(FakeAsync time, LocalGameService service) {
  while (true) {
    final item = service.room!.round!.nextBallotItem;
    if (item == null) break;
    service.castVote(item.id, VoteChoice.skip);
  }
  time.elapse(_timing.voting.$2);
}

AnswerLine _myLine(LocalGameService service, Category category) {
  final lines = service.room!.round!.results!.lines[service.localPlayerId]!;
  return lines.firstWhere((line) => line.category == category);
}

void main() {
  test('smart check: known words skip the vote and score', () {
    fakeAsync((time) {
      final service = _playToVoting(time, AnswerCheck.smart);

      final ballot = service.room!.round!.ballot;
      expect(
        ballot.where((item) => item.category == Category.animal),
        isEmpty,
        reason: "the bots' Monkey is a known animal",
      );
      expect(
        ballot.where((item) => item.category == Category.food),
        hasLength(1),
        reason: 'Monkey is not a known food, so it is voted on',
      );

      _finishVoting(time, service);
      final mango = _myLine(service, Category.food);
      expect(mango.verdict, AnswerVerdict.valid);
      expect(mango.byWordList, isTrue);
      expect(mango.points, 1000);
      service.dispose();
    });
  });

  test('auto only: nothing is voted on, and unknown words are wrong', () {
    fakeAsync((time) {
      final service = _playToVoting(time, AnswerCheck.auto);

      expect(service.room!.round!.ballot, isEmpty);
      expect(service.room!.round!.voteDeadline, isNull);

      time.elapse(_timing.voting.$2);
      expect(service.room!.phase, GamePhase.results);
      final moose = _myLine(service, Category.animal);
      expect(moose.verdict, AnswerVerdict.invalid);
      expect(moose.byWordList, isTrue);
      expect(_myLine(service, Category.food).verdict, AnswerVerdict.valid);
      expect(
        service.room!.scores[service.localPlayerId]!.validationPoints,
        0,
        reason: 'nobody voted, so nobody earns vote points',
      );
      service.dispose();
    });
  });

  test('players vote: the word list is not used', () {
    fakeAsync((time) {
      final service = _playToVoting(time, AnswerCheck.vote);

      final animals = service.room!.round!.ballot.where(
        (item) => item.category == Category.animal,
      );
      expect(animals.map((item) => item.text), ['Monkey']);
      service.dispose();
    });
  });

  test('before the word list loads, answers are voted on', () {
    fakeAsync((time) {
      final service = LocalGameService(
        random: Random(3),
        createBot: (_) => _MonkeyBot(),
        // Never finishes loading during this game.
        loadWords: () => Completer<WordList>().future,
      );
      service.createRoom(
        playerName: 'Sam',
        playerCount: 3,
        settings: GameSettings(answerCheck: AnswerCheck.auto),
      );
      time.elapse(const Duration(seconds: 4));
      service.startRound();
      service.selectLetter('M');
      time.elapse(_timing.letterReveal);
      time.elapse(GameRules.answerTime);

      expect(service.room!.round!.ballot, isNotEmpty);
      service.dispose();
    });
  });

  test('the word list loads once, when a room opens', () {
    fakeAsync((time) {
      var loads = 0;
      final service = LocalGameService(
        random: Random(3),
        loadWords: () async {
          loads++;
          return _words;
        },
      );

      service.createRoom(playerName: 'Sam', playerCount: 3);
      time.flushMicrotasks();
      service.createRoom(playerName: 'Sam', playerCount: 3);
      time.flushMicrotasks();

      expect(loads, 1);
      service.dispose();
    });
  });
}
