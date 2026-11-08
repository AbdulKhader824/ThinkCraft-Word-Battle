import 'category.dart';

/// How answers are judged.
enum AnswerCheck {
  /// Players vote on every answer.
  vote('Players vote', 'Everyone votes on every answer'),

  /// Answers in the word list are correct; players vote on the rest.
  smart('Smart check', 'Known words count at once; vote on the rest'),

  /// Answers in the word list are correct and the rest are wrong, with no
  /// voting at all.
  auto('Auto only', 'No voting: the word list decides');

  const AnswerCheck(this.label, this.detail);

  final String label;
  final String detail;
}

/// How well bots play. Bots judge answers the same way at every level;
/// only their own answers change.
enum BotLevel {
  /// Everyday words only, and more blanks.
  easy('Easy', 'Everyday words, and they miss a few'),

  /// Good answers, now and then a less common one.
  medium('Medium', 'Good answers, sometimes a surprising one'),

  /// Rare words from the big word list, which few players think of.
  hard('Hard', 'Rare words, hard to beat');

  const BotLevel(this.label, this.detail);

  final String label;
  final String detail;
}

/// How a room is played: how many rounds, how long each round's timer runs,
/// and which categories. The host chooses these when creating the room.
class GameSettings {
  GameSettings({
    this.rounds = defaultRounds,
    this.answerSeconds = defaultAnswerSeconds,
    Iterable<Category> categories = Category.defaults,
    this.answerCheck = AnswerCheck.smart,
    this.botLevel = BotLevel.medium,
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

  /// 3 rounds of 90 seconds with the classic six categories.
  static final standard = GameSettings();

  final int rounds;
  final int answerSeconds;
  final List<Category> categories;

  /// How answers are judged. Smart check by default, so voting is short.
  final AnswerCheck answerCheck;

  /// How well the room's bots play, if it has any. Medium by default.
  final BotLevel botLevel;

  Duration get answerTime => Duration(seconds: answerSeconds);

  bool get usesEveryCategory => categories.length == Category.values.length;
}
