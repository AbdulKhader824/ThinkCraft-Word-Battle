import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/rules/answer_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/scoring_rules.dart';

const _food = Category.food;

/// Plays out one category: [typed] maps players to their answers, and
/// [ballots] maps each answer's text to its votes by voter.
RoundResults _score(
  Map<String, String> typed, {
  required List<String> players,
  Map<String, Map<String, bool>> ballots = const {},
}) {
  final answers = [
    for (final player in players)
      Answer(playerId: player, category: _food, text: typed[player] ?? ''),
  ];
  final groups = AnswerRules.groupAnswers(
    answers: answers,
    letter: 'M',
    playerIds: players,
  );
  final votes = <Vote>[
    for (final MapEntry(key: text, value: voters) in ballots.entries)
      for (final MapEntry(key: voter, value: isValid) in voters.entries)
        Vote(
          voterId: voter,
          groupId: groups.firstWhere((g) => g.text == text).id,
          isValid: isValid,
        ),
  ];
  return ScoringRules.scoreRound(
    playerIds: players,
    answers: answers,
    groups: groups,
    votes: votes,
  );
}

void main() {
  group('answerPointsEach', () {
    const expected = {
      1: 1000,
      2: 500,
      3: 333,
      4: 250,
      5: 200,
      6: 167,
      7: 143,
      8: 125,
    };

    expected.forEach((sharers, hundredths) {
      test('$sharers sharing an answer score $hundredths hundredths', () {
        expect(ScoringRules.answerPointsEach(sharers), hundredths);
      });
    });

    test('the spec examples: 10, 5 and 3.33', () {
      expect(ScoringRules.formatPoints(ScoringRules.answerPointsEach(1)), '10');
      expect(ScoringRules.formatPoints(ScoringRules.answerPointsEach(2)), '5');
      expect(
        ScoringRules.formatPoints(ScoringRules.answerPointsEach(3)),
        '3.33',
      );
    });
  });

  group('answer points', () {
    test('a unique valid answer scores 10', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'b': true, 'c': true},
        },
      );

      expect(results.scores['a']!.answerPoints, 1000);
    });

    test('3 players sharing a valid answer score 3.33 each', () {
      final results = _score(
        {'a': 'Mango', 'b': 'mango', 'c': 'MANGO'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'d': true},
        },
      );

      for (final player in ['a', 'b', 'c']) {
        expect(results.scores[player]!.answerPoints, 333);
      }
    });

    test('an invalid answer scores 0', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'b': false, 'c': false},
        },
      );

      expect(results.scores['a']!.answerPoints, 0);
    });

    test('an empty answer scores 0', () {
      final results = _score({}, players: ['a', 'b']);

      expect(results.scores['a']!.answerPoints, 0);
      expect(results.scores['b']!.answerPoints, 0);
    });

    test('a wrong-letter answer scores 0 with no vote', () {
      final results = _score({'a': 'Banana'}, players: ['a', 'b', 'c']);

      expect(results.scores['a']!.answerPoints, 0);
    });

    test('a disputed answer scores 0', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'b': true, 'c': false},
        },
      );

      expect(results.scores['a']!.answerPoints, 0);
    });

    test('an answer nobody voted on is disputed and scores 0', () {
      final results = _score({'a': 'Mango'}, players: ['a', 'b', 'c']);

      expect(results.scores['a']!.answerPoints, 0);
    });
  });

  group('validation points', () {
    test('majority voters gain 1 and minority voters lose 1', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'b': true, 'c': true, 'd': false},
        },
      );

      expect(results.scores['b']!.validationPoints, 1);
      expect(results.scores['c']!.validationPoints, 1);
      expect(results.scores['d']!.validationPoints, -1);
    });

    test('voting an answer out earns the majority a point', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'b': false, 'c': false, 'd': true},
        },
      );

      expect(results.scores['b']!.validationPoints, 1);
      expect(results.scores['d']!.validationPoints, -1);
    });

    test('a tie gives voters 0', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'b': true, 'c': false},
        },
      );

      expect(results.scores['b']!.validationPoints, 0);
      expect(results.scores['c']!.validationPoints, 0);
    });

    test('a skipped vote scores 0', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'b': true, 'c': true},
        },
      );

      expect(results.scores['d']!.validationPoints, 0);
    });

    test('answer authors get no validation points for that answer', () {
      final results = _score(
        {'a': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'b': true, 'c': true},
        },
      );

      expect(results.scores['a']!.validationPoints, 0);
    });

    test('stay separate from answer points', () {
      final results = _score(
        {'a': 'Mango', 'b': 'Melon'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'b': true, 'c': true, 'd': true},
          'Melon': {'a': true, 'c': true, 'd': true},
        },
      );

      final line = results.scores['a']!;
      expect(line.answerPoints, 1000);
      expect(line.validationPoints, 1);
      expect(line.total, 1100);
    });
  });

  group('edge cases', () {
    test('everyone sharing an answer splits the points, with no voters', () {
      final results = _score({'a': 'Mango', 'b': 'mango'}, players: ['a', 'b']);

      expect(results.scores['a']!.answerPoints, 500);
      expect(results.scores['b']!.answerPoints, 500);
      expect(results.scores['a']!.validationPoints, 0);
    });

    test('in a 2-player game the voter decides but gains nothing', () {
      final results = _score(
        {'a': 'Mango', 'b': 'Melon'},
        players: ['a', 'b'],
        ballots: {
          'Mango': {'b': true},
          'Melon': {'a': false},
        },
      );

      expect(results.scores['a']!.answerPoints, 1000);
      expect(results.scores['b']!.answerPoints, 0);
      expect(results.scores['a']!.validationPoints, 0);
      expect(results.scores['b']!.validationPoints, 0);
    });

    test('a lone voter in a bigger game gains nothing either', () {
      final results = _score(
        {'a': 'Mango', 'b': 'Mango'},
        players: ['a', 'b', 'c'],
        ballots: {
          'Mango': {'c': false},
        },
      );

      expect(results.scores['a']!.answerPoints, 0);
      expect(results.scores['c']!.validationPoints, 0);
    });
  });

  group('answer lines', () {
    test('show each answer, its verdict and its points', () {
      final results = _score(
        {'a': 'Mango', 'b': 'Banana'},
        players: ['a', 'b', 'c', 'd'],
        ballots: {
          'Mango': {'b': true, 'c': true, 'd': true},
        },
      );

      final good = results.lines['a']!.single;
      expect(good.text, 'Mango');
      expect(good.verdict, AnswerVerdict.valid);
      expect(good.points, 1000);

      final bad = results.lines['b']!.single;
      expect(bad.verdict, AnswerVerdict.invalid);
      expect(bad.points, 0);
    });

    test('mark empty answers with no verdict', () {
      final results = _score({}, players: ['a', 'b']);

      final line = results.lines['a']!.single;
      expect(line.isEmpty, isTrue);
      expect(line.verdict, isNull);
    });
  });

  group('rank', () {
    const order = ['a', 'b', 'c', 'd'];

    test('sorts by total, highest first', () {
      final ranked = ScoringRules.rank(
        {
          'a': const ScoreLine(answerPoints: 500),
          'b': const ScoreLine(answerPoints: 1500),
          'c': const ScoreLine(answerPoints: 1000),
        },
        ['a', 'b', 'c'],
      );

      expect(ranked.map((e) => e.playerId), ['b', 'c', 'a']);
      expect(ranked.map((e) => e.rank), [1, 2, 3]);
    });

    test('ties share a rank, and the next rank is skipped', () {
      final ranked = ScoringRules.rank({
        'a': const ScoreLine(answerPoints: 1000),
        'b': const ScoreLine(answerPoints: 2000),
        'c': const ScoreLine(answerPoints: 1000),
        'd': const ScoreLine(),
      }, order);

      expect(ranked.map((e) => e.playerId), ['b', 'a', 'c', 'd']);
      expect(ranked.map((e) => e.rank), [1, 2, 2, 4]);
    });

    test('compares totals, including validation points', () {
      final ranked = ScoringRules.rank(
        {
          'a': const ScoreLine(answerPoints: 1000, validationPoints: -1),
          'b': const ScoreLine(answerPoints: 800, validationPoints: 1),
        },
        ['a', 'b'],
      );

      expect(ranked.map((e) => e.rank), [1, 1]);
    });

    test('players with no score yet count as 0', () {
      final ranked = ScoringRules.rank({}, ['a', 'b']);

      expect(ranked.map((e) => e.rank), [1, 1]);
    });
  });

  group('formatPoints', () {
    const cases = {
      1000: '10',
      0: '0',
      333: '3.33',
      250: '2.5',
      125: '1.25',
      -100: '-1',
      -67: '-0.67',
      -250: '-2.5',
      1166: '11.66',
    };

    cases.forEach((hundredths, text) {
      test('$hundredths is shown as $text', () {
        expect(ScoringRules.formatPoints(hundredths), text);
      });
    });
  });

  test('ScoreLines add up, keeping points separate', () {
    const first = ScoreLine(answerPoints: 333, validationPoints: 1);
    const second = ScoreLine(answerPoints: 1000, validationPoints: -2);

    final sum = first + second;

    expect(sum.answerPoints, 1333);
    expect(sum.validationPoints, -1);
    expect(sum.total, 1233);
  });
}
