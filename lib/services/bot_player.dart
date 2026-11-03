import 'dart:math';

import '../models/category.dart';
import 'word_bank.dart';

/// Chooses a simulated player's answers.
///
/// Most answers are good, some are blank, and some are deliberately wrong: a
/// real word for the letter, but from another category. That gives players
/// something to catch when voting arrives.
class BotPlayer {
  BotPlayer({required this.random});

  static const blankChance = 0.1;
  static const wrongChance = 0.15;

  final Random random;

  Map<Category, String> answersFor(String letter) {
    return {
      for (final category in Category.values)
        category: _answerFor(letter, category),
    };
  }

  String _answerFor(String letter, Category category) {
    final roll = random.nextDouble();
    if (roll < blankChance) return '';
    if (roll < blankChance + wrongChance) {
      return _pick(WordBank.wordsFor(letter, _otherCategory(category)));
    }
    return _pick(WordBank.wordsFor(letter, category));
  }

  Category _otherCategory(Category category) {
    final others = Category.values.where((other) => other != category).toList();
    return others[random.nextInt(others.length)];
  }

  String _pick(List<String> words) => words[random.nextInt(words.length)];
}
