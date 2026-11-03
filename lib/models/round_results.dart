import 'answer_group.dart';
import 'category.dart';

/// A player's points. Answer points and validation points stay separate.
class ScoreLine {
  const ScoreLine({this.answerPoints = 0, this.validationPoints = 0});

  /// Answer points in whole hundredths, so 3.33 is stored as 333.
  final int answerPoints;

  /// Validator points, always whole numbers such as +1 or -1.
  final int validationPoints;

  /// Both kinds added together, in hundredths.
  int get total => answerPoints + validationPoints * 100;

  ScoreLine operator +(ScoreLine other) {
    return ScoreLine(
      answerPoints: answerPoints + other.answerPoints,
      validationPoints: validationPoints + other.validationPoints,
    );
  }
}

/// One player's result for one category.
class AnswerLine {
  const AnswerLine({
    required this.category,
    required this.text,
    required this.verdict,
    required this.points,
  });

  final Category category;
  final String text;

  /// Null for an empty answer.
  final AnswerVerdict? verdict;

  /// Points earned, in hundredths.
  final int points;

  bool get isEmpty => text.isEmpty;
}

/// Everything decided by a finished round.
class RoundResults {
  RoundResults({
    required Map<String, ScoreLine> scores,
    required Map<String, List<AnswerLine>> lines,
  }) : scores = Map.unmodifiable(scores),
       lines = Map.unmodifiable(lines);

  /// This round's points by player id.
  final Map<String, ScoreLine> scores;

  /// Each player's answers by player id.
  final Map<String, List<AnswerLine>> lines;
}

/// A player's place on the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.rank,
    required this.score,
  });

  final String playerId;
  final int rank;
  final ScoreLine score;
}
