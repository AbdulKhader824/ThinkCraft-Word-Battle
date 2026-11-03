import 'dart:math';

import '../models/category.dart';
import 'word_bank.dart';

/// Chooses a simulated player's answers.
///
/// Most answers are good, some are blank, and some are deliberately wrong: a
/// real word for the letter, but from another category. That gives players
/// something to catch when voting.
class BotPlayer {
  BotPlayer({required this.random});

  static const blankChance = 0.1;
  static const wrongChance = 0.15;
  static const skipChance = 0.05;

  /// How often a bot judges a word it knows correctly.
  static const accuracy = 0.92;

  /// How often a bot accepts a word it has never seen, such as a player's
  /// real answer that isn't in the word bank.
  static const trustChance = 0.75;

  final Random random;

  Map<Category, String> answersFor(String letter) {
    return {
      for (final category in Category.values)
        category: _answerFor(letter, category),
    };
  }

  /// Decides a vote: true for valid, false for invalid, null to skip.
  bool? voteOn(Category category, String letter, String text) {
    if (random.nextDouble() < skipChance) return null;

    if (_isListed(text, letter, category)) {
      return random.nextDouble() < accuracy;
    }
    final isOtherCategory = Category.values.any(
      (other) => other != category && _isListed(text, letter, other),
    );
    if (isOtherCategory) return random.nextDouble() >= accuracy;

    return random.nextDouble() < trustChance;
  }

  bool _isListed(String text, String letter, Category category) {
    final target = text.toLowerCase();
    return WordBank.wordsFor(
      letter,
      category,
    ).any((word) => word.toLowerCase() == target);
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
