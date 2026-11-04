import 'category.dart';

/// How a room is played: how many rounds, how long each round's timer runs,
/// and which categories. The host chooses these when creating the room.
class GameSettings {
  GameSettings({
    this.rounds = defaultRounds,
    this.answerSeconds = defaultAnswerSeconds,
    Iterable<Category> categories = Category.values,
  }) : categories = List.unmodifiable(
         // Always in the standard order, whatever order they were picked in.
         Category.values.where(categories.contains),
       ) {
    if (!roundOptions.contains(rounds)) {
      throw ArgumentError.value(rounds, 'rounds', 'Not a round option.');
    }
    if (!answerSecondsOptions.contains(answerSeconds)) {
      throw ArgumentError.value(
        answerSeconds,
        'answerSeconds',
        'Not a timer option.',
      );
    }
    if (this.categories.isEmpty) {
      throw ArgumentError.value(categories, 'categories', 'Pick at least 1.');
    }
  }

  /// Ten rounds use at most 10 of the 26 letters, so a game never runs out.
  static const roundOptions = [1, 3, 5, 10];
  static const defaultRounds = 3;

  /// How long players have to answer each round.
  static const answerSecondsOptions = [30, 60, 90];
  static const defaultAnswerSeconds = 90;

  /// 3 rounds of 90 seconds with all six categories.
  static final standard = GameSettings();

  final int rounds;
  final int answerSeconds;
  final List<Category> categories;

  Duration get answerTime => Duration(seconds: answerSeconds);

  bool get usesEveryCategory => categories.length == Category.values.length;
}
