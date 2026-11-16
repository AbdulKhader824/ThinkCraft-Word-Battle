import 'dart:math';

import '../../models/impostor_room.dart';

/// The rules of The Impostor: who is picked, who speaks first, whether the
/// Impostor was caught, and the points.
abstract final class ImpostorRules {
  /// For voting for the Impostor.
  static const rightVotePoints = 3;

  /// For every normal player when the Impostor is caught.
  static const teamBonus = 1;

  /// For the Impostor, for each player who voted for someone else.
  static const fooledPoints = 2;

  /// For the Impostor when they aren't caught.
  static const notCaughtPoints = 3;

  /// For the Impostor when they pick the right word, caught or not.
  static const rightGuessPoints = 3;

  /// How many words the Impostor picks from, the real one included.
  static const guessChoiceCount = 6;

  /// Each player's chance of being the Impostor. Everyone starts the same,
  /// and each time a player has been the Impostor their chance halves, so
  /// anyone can still be picked, even twice in a row.
  static Map<String, double> impostorChances(
    List<String> playerIds,
    Map<String, int> timesImpostor,
  ) {
    final weights = {
      for (final id in playerIds) id: pow(0.5, timesImpostor[id] ?? 0),
    };
    final total = weights.values.fold<num>(0, (sum, weight) => sum + weight);
    return {
      for (final MapEntry(:key, :value) in weights.entries) key: value / total,
    };
  }

  /// Picks this round's Impostor from [playerIds].
  static String pickImpostor(
    List<String> playerIds,
    Map<String, int> timesImpostor,
    Random random,
  ) {
    final chances = impostorChances(playerIds, timesImpostor);
    var roll = random.nextDouble();
    for (final id in playerIds) {
      roll -= chances[id]!;
      if (roll < 0) return id;
    }
    return playerIds.last;
  }

  /// The clue order: everyone in a random order, [turns] times round, and
  /// never starting with the Impostor, who would have nothing to go on.
  static List<String> clueOrder(
    List<String> playerIds,
    String impostorId,
    int turns,
    Random random,
  ) {
    final order = [...playerIds]..shuffle(random);
    if (order.length > 1 && order.first == impostorId) {
      final swap = 1 + random.nextInt(order.length - 1);
      order[0] = order[swap];
      order[swap] = impostorId;
    }
    return [for (var turn = 0; turn < turns; turn++) ...order];
  }

  /// How many votes each player got.
  static Map<String, int> tally(Map<String, String> votes) {
    final counts = <String, int>{};
    for (final target in votes.values) {
      counts[target] = (counts[target] ?? 0) + 1;
    }
    return counts;
  }

  /// True when the Impostor got more votes than anyone else. A tie, or no
  /// votes at all, means they weren't caught.
  static bool isCaught(Map<String, String> votes, String impostorId) {
    final counts = tally(votes);
    final theirs = counts[impostorId] ?? 0;
    if (theirs == 0) return false;
    return counts.entries.every(
      (entry) => entry.key == impostorId || entry.value < theirs,
    );
  }

  /// What everyone won this round.
  ///
  /// [playerIds] are the players still in the room, the Impostor included.
  /// Players who didn't vote in time get no vote points and don't count as
  /// fooled.
  static Map<String, int> roundPoints({
    required List<String> playerIds,
    required String impostorId,
    required Map<String, String> votes,
    required bool guessedRight,
  }) {
    final caught = isCaught(votes, impostorId);
    final points = <String, int>{};
    var fooled = 0;
    for (final id in playerIds) {
      if (id == impostorId) continue;
      final vote = votes[id];
      var won = 0;
      if (vote == impostorId) won += rightVotePoints;
      if (vote != null && vote != impostorId) fooled++;
      if (caught) won += teamBonus;
      points[id] = won;
    }
    points[impostorId] =
        fooled * fooledPoints +
        (caught ? 0 : notCaughtPoints) +
        (guessedRight ? rightGuessPoints : 0);
    return points;
  }

  /// The players with the most right votes, if anyone has one.
  static List<String> bestDetectives(Map<String, ImpostorScore> scores) =>
      _mostOf(scores, (score) => score.rightVotes);

  /// The players with the most points won as the Impostor, if anyone won
  /// any.
  static List<String> mastersOfDisguise(Map<String, ImpostorScore> scores) =>
      _mostOf(scores, (score) => score.impostorPoints);

  static List<String> _mostOf(
    Map<String, ImpostorScore> scores,
    int Function(ImpostorScore score) value,
  ) {
    final best = scores.values.map(value).fold(0, max);
    if (best == 0) return const [];
    return [
      for (final MapEntry(:key, value: score) in scores.entries)
        if (value(score) == best) key,
    ];
  }
}
