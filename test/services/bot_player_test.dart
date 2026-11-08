import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/services/bot_player.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/word_check.dart';
import 'package:thinkcraft_word_battle/services/word_bank.dart';

void main() {
  final bot = BotPlayer(random: Random(7));

  test('answers all six categories', () {
    expect(bot.answersFor('M').keys, unorderedEquals(Category.values));
  });

  test('never uses the wrong letter, for any letter', () {
    for (final letter in GameRules.letters) {
      for (var game = 0; game < 50; game++) {
        for (final answer in bot.answersFor(letter).values) {
          expect(GameRules.startsWithLetter(answer, letter), isTrue);
        }
      }
    }
  });

  group('voteOn', () {
    double validShare(String text, Category category) {
      var valid = 0;
      var total = 0;
      for (var game = 0; game < 2000; game++) {
        final vote = bot.voteOn(category, 'M', text);
        if (vote == null) continue;
        total++;
        if (vote) valid++;
      }
      return valid / total;
    }

    test('usually accepts a good answer', () {
      expect(validShare('Mango', Category.food), greaterThan(0.85));
    });

    test('usually rejects a word from another category', () {
      expect(validShare('Mango', Category.animal), lessThan(0.15));
    });

    test('ignores capitals when recognising a word', () {
      expect(validShare('MANGO', Category.food), greaterThan(0.85));
    });

    test('tends to trust words it does not know', () {
      expect(validShare('Marmalade', Category.food), closeTo(0.75, 0.05));
    });

    test('sometimes skips', () {
      final votes = [
        for (var game = 0; game < 2000; game++)
          bot.voteOn(Category.food, 'M', 'Mango'),
      ];

      expect(votes.where((vote) => vote == null), isNotEmpty);
    });
  });

  test('mixes good, blank and deliberately wrong answers', () {
    var good = 0;
    var blank = 0;
    var wrong = 0;

    for (var game = 0; game < 2000; game++) {
      bot.answersFor('M').forEach((category, answer) {
        if (answer.isEmpty) {
          blank++;
        } else if (WordBank.wordsFor('M', category).contains(answer)) {
          good++;
        } else {
          wrong++;
        }
      });
    }

    final total = good + blank + wrong;
    expect(blank / total, closeTo(BotStyle.medium.blankChance, 0.02));
    expect(wrong / total, closeTo(BotStyle.medium.wrongChance, 0.02));
    expect(good / total, greaterThan(0.7));
  });

  group('levels', () {
    // A word list of rare animals, none of them in the word bank.
    final rare = SetWordList({
      Category.animal: [
        'Markhor',
        'Margay',
        'Mudpuppy',
        'Muntjac',
        'Midwife toad',
        'Mexican mole lizard',
        'M2 mouse', // Not typeable: has a digit.
        'Mshitakusa', // Real words can hide rude letters.
        'Mapanalbird', // Bots skip these too.
        'Malagasy giant jumping rat', // Too long for any level.
      ],
    });
    const rareAnimals = {
      'Markhor',
      'Margay',
      'Mudpuppy',
      'Muntjac',
      'Midwife Toad',
      'Mexican Mole Lizard',
    };

    Map<String, int> share(BotLevel level, WordList? words) {
      final counts = {'blank': 0, 'rare': 0, 'bank': 0, 'other': 0};
      final player = BotPlayer(random: Random(3));
      for (var game = 0; game < 3000; game++) {
        final answer = player.answersFor(
          'M',
          const [Category.animal],
          level,
          words,
        )[Category.animal]!;
        final String kind;
        if (answer.isEmpty) {
          kind = 'blank';
        } else if (rareAnimals.contains(answer)) {
          kind = 'rare';
        } else if (WordBank.wordsFor('M', Category.animal).contains(answer)) {
          kind = 'bank';
        } else {
          kind = 'other';
        }
        counts[kind] = counts[kind]! + 1;
      }
      return counts;
    }

    test('easy bots only use everyday words, and leave more blank', () {
      final counts = share(BotLevel.easy, rare);
      expect(counts['rare'], 0);
      expect(counts['blank']! / 3000, closeTo(BotStyle.easy.blankChance, 0.03));
    });

    test('hard bots mostly give rare words from the word list', () {
      final counts = share(BotLevel.hard, rare);
      expect(counts['rare']! / 3000, greaterThan(0.55));
      expect(counts['blank']! / 3000, closeTo(BotStyle.hard.blankChance, 0.02));
    });

    test('medium bots sometimes give a short rare word', () {
      final counts = share(BotLevel.medium, rare);
      expect(counts['rare']! / 3000, greaterThan(0.08));
      expect(counts['bank']!, greaterThan(counts['rare']!));
    });

    test('word list answers are typeable and written like a player', () {
      final player = BotPlayer(random: Random(5));
      for (var game = 0; game < 2000; game++) {
        final answer = player.answersFor(
          'M',
          const [Category.animal],
          BotLevel.hard,
          rare,
        )[Category.animal]!;
        expect(answer, isNot(contains('2')));
        expect(answer, isNot('Malagasy Giant Jumping Rat'));
        expect(answer, isNot('Mshitakusa'));
        expect(answer, isNot('Mapanalbird'));
      }
    });

    test('without the word list, every level uses the word bank', () {
      final counts = share(BotLevel.hard, null);
      expect(counts['rare'], 0);
      expect(counts['bank']! / 3000, greaterThan(0.8));
    });
  });
}
