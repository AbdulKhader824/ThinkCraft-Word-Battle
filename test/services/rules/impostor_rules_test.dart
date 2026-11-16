import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/services/impostor_words.dart';
import 'package:thinkcraft_word_battle/services/rules/impostor_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/rude_words.dart';

void main() {
  const five = ['riya', 'ali', 'meera', 'sam', 'zara'];

  group('scoring', () {
    test('caught, and the Impostor guesses right', () {
      final points = ImpostorRules.roundPoints(
        playerIds: five,
        impostorId: 'riya',
        votes: {'ali': 'riya', 'meera': 'riya', 'sam': 'riya', 'zara': 'ali'},
        guessedRight: true,
      );
      expect(points, {
        'ali': 4,
        'meera': 4,
        'sam': 4,
        'zara': 1,
        'riya': 2 + 3,
      });
    });

    test('not caught, and the Impostor guesses wrong', () {
      final points = ImpostorRules.roundPoints(
        playerIds: five,
        impostorId: 'riya',
        votes: {'ali': 'riya', 'meera': 'zara', 'sam': 'zara', 'zara': 'sam'},
        guessedRight: false,
      );
      expect(points, {'ali': 3, 'meera': 0, 'sam': 0, 'zara': 0, 'riya': 9});
    });

    test('a right guess is worth the same, caught or not', () {
      int impostorBonus(Map<String, String> votes) {
        int points(bool right) => ImpostorRules.roundPoints(
          playerIds: five,
          impostorId: 'riya',
          votes: votes,
          guessedRight: right,
        )['riya']!;
        return points(true) - points(false);
      }

      const caught = {'ali': 'riya', 'meera': 'riya', 'sam': 'riya'};
      const free = {'ali': 'sam', 'meera': 'sam', 'sam': 'ali'};
      expect(impostorBonus(caught), ImpostorRules.rightGuessPoints);
      expect(impostorBonus(free), ImpostorRules.rightGuessPoints);
    });

    test('players who did not vote get nothing and are not fooled', () {
      final points = ImpostorRules.roundPoints(
        playerIds: five,
        impostorId: 'riya',
        votes: {'ali': 'sam'},
        guessedRight: false,
      );
      expect(points['meera'], 0);
      expect(points['riya'], 2 + 3, reason: 'one fooled, not caught');
    });
  });

  group('caught', () {
    test('most votes on the Impostor catches them', () {
      expect(
        ImpostorRules.isCaught({'a': 'x', 'b': 'x', 'c': 'y'}, 'x'),
        isTrue,
      );
    });

    test('a tie, or no votes, means not caught', () {
      expect(
        ImpostorRules.isCaught({'a': 'x', 'b': 'y', 'x': 'a', 'y': 'a'}, 'x'),
        isFalse,
      );
      expect(ImpostorRules.isCaught({}, 'x'), isFalse);
    });

    test('someone else with more votes means not caught', () {
      expect(
        ImpostorRules.isCaught({'a': 'y', 'b': 'y', 'c': 'x'}, 'x'),
        isFalse,
      );
    });
  });

  group('picking the Impostor', () {
    test('everyone starts with the same chance', () {
      final chances = ImpostorRules.impostorChances(five, {});
      for (final chance in chances.values) {
        expect(chance, closeTo(0.2, 1e-9));
      }
    });

    test('each time as the Impostor halves the chance', () {
      final once = ImpostorRules.impostorChances(five, {'riya': 1});
      expect(once['riya'], closeTo(0.5 / 4.5, 1e-9));
      expect(once['ali'], closeTo(1 / 4.5, 1e-9));

      final twice = ImpostorRules.impostorChances(five, {'riya': 2});
      expect(twice['riya'], closeTo(0.25 / 4.25, 1e-9));
    });

    test('picks follow the chances, and repeats can happen', () {
      final random = Random(7);
      final counts = <String, int>{};
      for (var roll = 0; roll < 9000; roll++) {
        final id = ImpostorRules.pickImpostor(five, {'riya': 1}, random);
        counts[id] = (counts[id] ?? 0) + 1;
      }
      // Riya: 1 in 9; each of the others: 2 in 9.
      expect(counts['riya']! / 9000, closeTo(1 / 9, 0.02));
      expect(counts['ali']! / 9000, closeTo(2 / 9, 0.02));
    });
  });

  test('the clue order goes round the right number of times and never '
      'starts with the Impostor', () {
    for (var seed = 0; seed < 50; seed++) {
      final order = ImpostorRules.clueOrder(five, 'riya', 2, Random(seed));
      expect(order, hasLength(10));
      expect(order.first, isNot('riya'));
      expect(order.sublist(0, 5), order.sublist(5));
      expect(order.toSet(), five.toSet());
    }
  });

  test('awards go to the most right votes and most Impostor points', () {
    const scores = {
      'a': ImpostorScore(points: 9, rightVotes: 2, impostorPoints: 0),
      'b': ImpostorScore(points: 9, rightVotes: 2, impostorPoints: 5),
      'c': ImpostorScore(points: 9, rightVotes: 0, impostorPoints: 9),
    };
    expect(ImpostorRules.bestDetectives(scores), ['a', 'b']);
    expect(ImpostorRules.mastersOfDisguise(scores), ['c']);
    expect(ImpostorRules.bestDetectives(const {'a': ImpostorScore()}), isEmpty);
  });

  group('words', () {
    test('about 300 words, unique, lower case and kind', () {
      final all = [
        for (final topic in ImpostorTopic.values)
          ...ImpostorWords.forTopic(topic),
      ];
      expect(all.length, greaterThanOrEqualTo(280));
      expect(all.toSet().length, all.length, reason: 'no word twice');
      for (final topic in ImpostorTopic.values) {
        expect(ImpostorWords.forTopic(topic).length, greaterThanOrEqualTo(40));
      }
      for (final word in all) {
        expect(word, matches(RegExp(r'^[a-z]+( [a-z]+)*$')));
        expect(soundsRude(word), isFalse, reason: word);
      }
    });

    test('six guess choices from the same topic, with the word among them', () {
      final random = Random(3);
      for (var pick = 0; pick < 30; pick++) {
        final result = ImpostorWords.pick(ImpostorTopic.values.toSet(), random);
        expect(result.choices, hasLength(6));
        expect(result.choices.toSet(), hasLength(6));
        expect(result.choices, contains(result.word));
        for (final choice in result.choices) {
          expect(ImpostorWords.forTopic(result.topic), contains(choice));
        }
      }
    });

    test('words never repeat until a topic runs out', () {
      final random = Random(9);
      final used = <String>{};
      final topic = {ImpostorTopic.food};
      final count = ImpostorWords.forTopic(ImpostorTopic.food).length;
      for (var pick = 0; pick < count; pick++) {
        final word = ImpostorWords.pick(topic, random, used: used).word;
        expect(used.add(word), isTrue, reason: '$word came twice');
      }
      // All used: it starts again rather than failing.
      expect(ImpostorWords.pick(topic, random, used: used).word, isNotEmpty);
    });

    test('only the chosen topics are used', () {
      final random = Random(1);
      for (var pick = 0; pick < 20; pick++) {
        final result = ImpostorWords.pick({
          ImpostorTopic.sports,
          ImpostorTopic.jobs,
        }, random);
        expect(result.topic, isIn([ImpostorTopic.sports, ImpostorTopic.jobs]));
      }
    });
  });

  test('settings check their choices', () {
    expect(() => ImpostorSettings(rounds: 4), throwsArgumentError);
    expect(() => ImpostorSettings(clueSeconds: 10), throwsArgumentError);
    expect(() => ImpostorSettings(clueTurns: 3), throwsArgumentError);
    expect(() => ImpostorSettings(topics: {}), throwsArgumentError);
    expect(ImpostorSettings().topics, hasLength(7));
  });
}
