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
