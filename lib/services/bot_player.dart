import 'dart:math';

import '../models/category.dart';
import '../models/game_settings.dart';
import 'rules/rude_words.dart';
import 'rules/word_check.dart';
import 'word_bank.dart';

/// How a [BotLevel] answers.
class BotStyle {
  const BotStyle({
    required this.blankChance,
    required this.wrongChance,
    required this.wordListChance,
    required this.maxWordListLength,
  });

  /// How often an answer is left blank.
  final double blankChance;

  /// How often an answer is deliberately wrong.
  final double wrongChance;

  /// How often a good answer comes from the big word list instead of the
  /// everyday word bank. Its words are rarer, so they are often unique.
  final double wordListChance;

  /// The longest word list answer this level gives, in letters. Short ones
  /// are more likely to be everyday words.
  final int maxWordListLength;

  static const easy = BotStyle(
    blankChance: 0.25,
    wrongChance: 0.15,
    wordListChance: 0,
    maxWordListLength: 0,
  );
  static const medium = BotStyle(
    blankChance: 0.1,
    wrongChance: 0.15,
    wordListChance: 0.25,
    maxWordListLength: 12,
  );
  static const hard = BotStyle(
    blankChance: 0.03,
    wrongChance: 0.07,
    wordListChance: 0.7,
    maxWordListLength: 22,
  );

  static BotStyle of(BotLevel level) => switch (level) {
    BotLevel.easy => easy,
    BotLevel.medium => medium,
    BotLevel.hard => hard,
  };
}

/// Chooses a simulated player's answers.
///
/// Most answers are good, some are blank, and some are deliberately wrong: a
/// real word for the letter, but from another category. That gives players
/// something to catch when voting. How often each happens, and how rare the
/// good answers are, depends on the room's [BotLevel].
class BotPlayer {
  BotPlayer({required this.random});

  static const skipChance = 0.05;

  /// How often a bot judges a word it knows correctly.
  static const accuracy = 0.92;

  /// How often a bot accepts a word it has never seen, such as a player's
  /// real answer that isn't in the word bank.
  static const trustChance = 0.75;

  final Random random;

  /// Answers for the room's [categories], at [level]. With [words], the
  /// big word list, good answers can be rarer ones from it; without it,
  /// such as while it's still loading, they come from the word bank. A
  /// deliberately wrong answer can still come from any category, which is
  /// what makes it wrong.
  Map<Category, String> answersFor(
    String letter, [
    Iterable<Category> categories = Category.values,
    BotLevel level = BotLevel.medium,
    WordList? words,
  ]) {
    final style = BotStyle.of(level);
    return {
      for (final category in categories)
        category: _answerFor(letter, category, style, words),
    };
  }

  /// Decides a vote: true for valid, false for invalid, null to skip.
  bool? voteOn(Category category, String letter, String text) {
    if (random.nextDouble() < skipChance) return null;

    if (_isListed(text, letter, category)) {
      return random.nextDouble() < accuracy;
    }
    final isOtherCategory = Category.values.any(
      (other) =>
          !category.related.contains(other) && _isListed(text, letter, other),
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

  String _answerFor(
    String letter,
    Category category,
    BotStyle style,
    WordList? words,
  ) {
    final roll = random.nextDouble();
    if (roll < style.blankChance) return '';
    if (roll < style.blankChance + style.wrongChance) {
      return _pick(WordBank.wordsFor(letter, _otherCategory(category)));
    }
    if (words != null && random.nextDouble() < style.wordListChance) {
      final listed = _fromWordList(words, letter, category, style);
      if (listed.isNotEmpty) return listed;
    }
    return _pick(WordBank.wordsFor(letter, category));
  }

  /// A random word list answer short enough for [style], written the way a
  /// player would type it ("Midwife Toad"), or '' when there is none.
  String _fromWordList(
    WordList words,
    String letter,
    Category category,
    BotStyle style,
  ) {
    final all = words.wordsStartingWith(category, letter);
    // A few tries is plenty: most words in the list are a fine length.
    for (var attempt = 0; attempt < 12 && all.isNotEmpty; attempt++) {
      final word = all[random.nextInt(all.length)];
      if (word.length <= style.maxWordListLength &&
          _looksTypeable(word) &&
          !soundsRude(word)) {
        return _titleCase(word);
      }
    }
    return '';
  }

  /// Letters and spaces only, in at most three words: no codes or numbers.
  static final _typeable = RegExp(r'^[a-z]+( [a-z]+){0,2}$');

  static bool _looksTypeable(String word) => _typeable.hasMatch(word);

  static String _titleCase(String word) => word
      .split(' ')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  /// A category whose words are wrong for [category]. Related ones, such
  /// as Bird for Animal, are skipped: an eagle is an animal too.
  Category _otherCategory(Category category) {
    final others = Category.values
        .where((other) => !category.related.contains(other))
        .toList();
    return others[random.nextInt(others.length)];
  }

  /// A random word, or a blank when there is none for this letter.
  String _pick(List<String> words) =>
      words.isEmpty ? '' : words[random.nextInt(words.length)];
}
