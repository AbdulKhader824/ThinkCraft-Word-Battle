import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

void main() {
  test('the standard game is 3 rounds of 90 seconds, every category', () {
    final settings = GameSettings.standard;

    expect(settings.rounds, 3);
    expect(settings.categories, Category.values);
    expect(settings.usesEveryCategory, isTrue);
  });

  test('offers 1, 3, 5 and 10 rounds', () {
    expect(GameSettings.roundOptions, [1, 3, 5, 10]);
  });

  test('never needs more letters than the alphabet has', () {
    final longest = GameSettings.roundOptions.reduce((a, b) => a > b ? a : b);

    expect(longest, lessThanOrEqualTo(GameRules.letters.length));
  });

  test('keeps categories in the standard order', () {
    final settings = GameSettings(
      categories: const [Category.brand, Category.animal, Category.food],
    );

    expect(settings.categories, [
      Category.animal,
      Category.food,
      Category.brand,
    ]);
    expect(settings.usesEveryCategory, isFalse);
  });

  test('ignores a category listed twice', () {
    final settings = GameSettings(
      categories: const [Category.food, Category.food],
    );

    expect(settings.categories, [Category.food]);
  });

  test('rejects a round count that is not an option', () {
    expect(() => GameSettings(rounds: 0), throwsArgumentError);
    expect(() => GameSettings(rounds: 4), throwsArgumentError);
  });

  test('the timer offers 30, 60 and 90 seconds, starting at 90', () {
    expect(GameSettings.answerSecondsOptions, [30, 60, 90]);
    expect(GameSettings.standard.answerSeconds, 90);
    expect(GameSettings.standard.answerTime, GameRules.answerTime);
  });

  test('turns the chosen seconds into a duration', () {
    final settings = GameSettings(answerSeconds: 30);

    expect(settings.answerTime, const Duration(seconds: 30));
  });

  test('rejects a timer that is not an option', () {
    expect(() => GameSettings(answerSeconds: 0), throwsArgumentError);
    expect(() => GameSettings(answerSeconds: 45), throwsArgumentError);
  });

  test('rejects having no categories', () {
    expect(() => GameSettings(categories: const []), throwsArgumentError);
  });
}
