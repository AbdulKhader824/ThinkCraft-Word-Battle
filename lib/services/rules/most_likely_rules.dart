import 'dart:math';

/// The rules of Most Likely To...: counting votes, who is most likely, and
/// the mind-reader points.
abstract final class MostLikelyRules {
  /// For voting for a player who got the most votes: reading the room.
  static const mindReaderPoints = 1;

  /// How many votes each player got. Players may vote for themselves.
  static Map<String, int> tally(Map<String, String> votes) {
    final counts = <String, int>{};
    for (final target in votes.values) {
      counts[target] = (counts[target] ?? 0) + 1;
    }
    return counts;
  }

  /// The players with the most votes: everyone tied for the most, or
  /// nobody when there were no votes.
  static Set<String> mostLikely(Map<String, String> votes) {
    final counts = tally(votes);
    final most = counts.values.fold(0, max);
    if (most == 0) return const {};
    return {
      for (final MapEntry(:key, :value) in counts.entries)
        if (value == most) key,
    };
  }

  /// What each voter won: [mindReaderPoints] for voting for a player who
  /// got the most votes, and nothing otherwise. Players who didn't vote
  /// aren't in it.
  static Map<String, int> points(Map<String, String> votes) {
    final top = mostLikely(votes);
    return {
      for (final MapEntry(key: voter, value: target) in votes.entries)
        voter: top.contains(target) ? mindReaderPoints : 0,
    };
  }

  /// [titles] with [question] added for each of [mostLikelyIds].
  static Map<String, List<String>> addTitle(
    Map<String, List<String>> titles,
    Set<String> mostLikelyIds,
    String question,
  ) {
    return {
      ...titles,
      for (final id in mostLikelyIds) id: [...?titles[id], question],
    };
  }

  /// [scores] with [roundPoints] added.
  static Map<String, int> addPoints(
    Map<String, int> scores,
    Map<String, int> roundPoints,
  ) {
    return {
      ...scores,
      for (final MapEntry(:key, :value) in roundPoints.entries)
        key: (scores[key] ?? 0) + value,
    };
  }

  /// The players with the most points, who share the win; nobody if
  /// nobody scored.
  static List<String> winners(Map<String, int> scores) {
    final best = scores.values.fold(0, max);
    if (best == 0) return const [];
    return [
      for (final MapEntry(:key, :value) in scores.entries)
        if (value == best) key,
    ];
  }
}
