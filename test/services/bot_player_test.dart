import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/services/bot_player.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';
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
    expect(blank / total, closeTo(BotPlayer.blankChance, 0.02));
    expect(wrong / total, closeTo(BotPlayer.wrongChance, 0.02));
    expect(good / total, greaterThan(0.7));
  });
}
