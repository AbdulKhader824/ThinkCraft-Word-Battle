import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';
import 'package:thinkcraft_word_battle/services/word_bank.dart';

void main() {
  test('every letter has at least two words in every category', () {
    for (final letter in GameRules.letters) {
      for (final category in Category.values) {
        final words = WordBank.wordsFor(letter, category);
        expect(
          words.length,
          greaterThanOrEqualTo(2),
          reason: '$letter ${category.label}',
        );
      }
    }
  });

  test('every word starts with its letter', () {
    for (final letter in GameRules.letters) {
      for (final category in Category.values) {
        for (final word in WordBank.wordsFor(letter, category)) {
          expect(
            GameRules.startsWithLetter(word, letter),
            isTrue,
            reason: '"$word" is listed under $letter',
          );
        }
      }
    }
  });

  test('no category lists the same word twice', () {
    for (final letter in GameRules.letters) {
      for (final category in Category.values) {
        final words = WordBank.wordsFor(letter, category);
        expect(words.toSet().length, words.length, reason: '$letter $category');
      }
    }
  });

  test('the spec example for M can be found', () {
    expect(WordBank.wordsFor('M', Category.animal), contains('Monkey'));
    expect(WordBank.wordsFor('M', Category.food), contains('Mango'));
    expect(WordBank.wordsFor('m', Category.brand), contains('Microsoft'));
  });
}
