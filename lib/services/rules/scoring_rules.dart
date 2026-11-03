import '../../models/answer.dart';
import '../../models/answer_group.dart';
import '../../models/round_results.dart';
import '../../models/vote.dart';
import 'answer_rules.dart';
import 'vote_rules.dart';

/// Turns answers and votes into points. Plain Dart, with no Flutter imports.
abstract final class ScoringRules {
  /// 10 points, in whole hundredths.
  static const _fullPoints = 1000;

  /// A lone vote isn't a majority, and would earn free points for rejecting
  /// everything, so validator points need at least this many votes.
  static const _minVotesForValidatorPoints = 2;

  /// Hundredths each player earns when [sharers] share a valid answer.
  static int answerPointsEach(int sharers) {
    return (_fullPoints / sharers).round();
  }

  static RoundResults scoreRound({
    required List<String> playerIds,
    required List<Answer> answers,
    required List<AnswerGroup> groups,
    required List<Vote> votes,
  }) {
    final verdicts = {
      for (final group in groups) group.id: VoteRules.verdictFor(group, votes),
    };
    final groupsById = {for (final group in groups) group.id: group};
    final answerPoints = {for (final player in playerIds) player: 0};
    final validationPoints = {for (final player in playerIds) player: 0};
    final lines = {for (final player in playerIds) player: <AnswerLine>[]};

    for (final answer in answers) {
      final id = AnswerRules.groupIdFor(answer);
      final group = groupsById[id];
      final points = group != null && verdicts[id] == AnswerVerdict.valid
          ? answerPointsEach(group.authorIds.length)
          : 0;

      answerPoints[answer.playerId] = answerPoints[answer.playerId]! + points;
      lines[answer.playerId]!.add(
        AnswerLine(
          category: answer.category,
          text: group?.text ?? '',
          verdict: verdicts[id],
          points: points,
        ),
      );
    }

    for (final group in groups.where((group) => group.needsVote)) {
      _addValidatorPoints(group, verdicts[group.id]!, votes, validationPoints);
    }

    return RoundResults(
      scores: {
        for (final player in playerIds)
          player: ScoreLine(
            answerPoints: answerPoints[player]!,
            validationPoints: validationPoints[player]!,
          ),
      },
      lines: lines,
    );
  }

  static void _addValidatorPoints(
    AnswerGroup group,
    AnswerVerdict verdict,
    List<Vote> votes,
    Map<String, int> points,
  ) {
    if (verdict == AnswerVerdict.disputed) return;

    final counted = votes.where((vote) => vote.groupId == group.id).toList();
    if (counted.length < _minVotesForValidatorPoints) return;

    final majorityIsValid = verdict == AnswerVerdict.valid;
    for (final vote in counted) {
      final change = vote.isValid == majorityIsValid ? 1 : -1;
      points[vote.voterId] = points[vote.voterId]! + change;
    }
  }

  /// Orders players by total, highest first. Tied players share a rank and
  /// the next rank is skipped, so 1, 2, 2, 4.
  static List<LeaderboardEntry> rank(
    Map<String, ScoreLine> scores,
    List<String> playerIds,
  ) {
    int totalOf(String id) => (scores[id] ?? const ScoreLine()).total;

    final sorted = [...playerIds.indexed]
      ..sort((a, b) {
        final byTotal = totalOf(b.$2).compareTo(totalOf(a.$2));
        return byTotal != 0 ? byTotal : a.$1.compareTo(b.$1);
      });

    final entries = <LeaderboardEntry>[];
    for (final (position, (_, id)) in sorted.indexed) {
      final isTied = position > 0 && totalOf(id) == entries.last.score.total;
      entries.add(
        LeaderboardEntry(
          playerId: id,
          rank: isTied ? entries.last.rank : position + 1,
          score: scores[id] ?? const ScoreLine(),
        ),
      );
    }
    return entries;
  }

  /// Shows hundredths as points, so 333 is "3.33" and 1000 is "10".
  static String formatPoints(int hundredths) {
    final sign = hundredths < 0 ? '-' : '';
    final size = hundredths.abs();
    final whole = size ~/ 100;
    final part = size % 100;

    if (part == 0) return '$sign$whole';
    final decimals = part.toString().padLeft(2, '0');
    return '$sign$whole.${decimals.replaceFirst(RegExp(r'0$'), '')}';
  }
}
