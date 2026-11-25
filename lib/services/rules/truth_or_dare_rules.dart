import 'dart:math';

import '../../models/truth_or_dare_game.dart';

/// Picks a card of a kind that hasn't been used yet; the game gives it the
/// level and the cards used so far.
typedef TodCardPicker = String Function(
  TodLevel level,
  TodKind kind,
  Set<String> used,
);

/// The rules of Truth or Dare: whose turn, cards, Done and Skip, lives and
/// the end of the game. Every move returns a new [TodGame].
abstract final class TruthOrDareRules {
  /// Starts a game with [names], each with a different face where there
  /// are enough, then spins for the first player.
  static TodGame start(
    List<String> names,
    TodSettings settings,
    Random random, {
    int avatarCount = 8,
  }) {
    if (names.length < TodGame.minPlayers ||
        names.length > TodGame.maxPlayers) {
      throw ArgumentError.value(names, 'names', 'Needs 2 to 12 players.');
    }
    final faces = List.generate(avatarCount, (index) => index)..shuffle(random);
    final game = TodGame(
      settings: settings,
      players: [
        for (final (index, name) in names.indexed)
          TodPlayer(name: name, avatarIndex: faces[index % faces.length]),
      ],
    );
    return spin(game, random);
  }

  /// Picks whose turn is next: someone still in who hasn't had a turn this
  /// round, never the same player twice in a row when there's a choice.
  /// When everyone has had a turn, the next round starts, or the game ends
  /// after the last round.
  static TodGame spin(TodGame game, Random random) {
    final stillIn = game.stillIn;
    if (stillIn.length < TodGame.minPlayers) return finish(game);

    var round = game.round;
    var taken = game.takenThisRound;
    var waiting = [
      for (final index in stillIn)
        if (!taken.contains(index)) index,
    ];
    if (waiting.isEmpty) {
      if (round >= game.settings.rounds) return finish(game);
      round++;
      taken = const {};
      waiting = stillIn;
    }
    final choices = waiting.length > 1
        ? [
            for (final index in waiting)
              if (index != game.current) index,
          ]
        : waiting;
    final next = choices[random.nextInt(choices.length)];
    return game.copyWith(
      phase: TodPhase.choose,
      round: round,
      takenThisRound: {...taken, next},
      previous: () => game.current,
      current: () => next,
      kind: () => null,
      card: () => null,
    );
  }

  /// The player picks Truth or Dare, and gets a card. There's no swapping
  /// it: the only way out is Skip, which costs a life.
  static TodGame choose(TodGame game, TodKind kind, TodCardPicker pick) {
    if (game.phase != TodPhase.choose) return game;
    final card = pick(game.settings.level, kind, game.usedCards);
    return game.copyWith(
      kind: () => kind,
      phase: TodPhase.card,
      card: () => card,
      usedCards: {...game.usedCards, card},
    );
  }

  /// They did it: a point, then the next turn.
  static TodGame done(TodGame game, Random random) {
    final index = game.current;
    final kind = game.kind;
    if (game.phase != TodPhase.card || index == null || kind == null) {
      return game;
    }
    final player = game.players[index];
    final updated = kind == TodKind.truth
        ? player.copyWith(truths: player.truths + 1)
        : player.copyWith(dares: player.dares + 1);
    return spin(_replace(game, index, updated), random);
  }

  /// They skipped: a life lost, and out after the last one. Then the next
  /// turn.
  static TodGame skip(TodGame game, Random random) {
    final index = game.current;
    if (game.phase != TodPhase.card || index == null) return game;
    final player = game.players[index];
    final updated = player.copyWith(skips: player.skips + 1);
    return spin(_replace(game, index, updated), random);
  }

  /// Ends the game now.
  static TodGame finish(TodGame game) => game.copyWith(
    phase: TodPhase.finished,
    kind: () => null,
    card: () => null,
  );

  static TodGame _replace(TodGame game, int index, TodPlayer player) =>
      game.copyWith(
        players: [
          for (final (place, old) in game.players.indexed)
            place == index ? player : old,
        ],
      );

  /// Players with the most points, who share the win; none if nobody
  /// scored. By place in the game's players.
  static List<int> winners(TodGame game) =>
      _mostOf(game, (player) => player.points);

  /// Bravest: the most dares done.
  static List<int> bravest(TodGame game) =>
      _mostOf(game, (player) => player.dares);

  /// Most honest: the most truths answered.
  static List<int> mostHonest(TodGame game) =>
      _mostOf(game, (player) => player.truths);

  static List<int> _mostOf(TodGame game, int Function(TodPlayer) value) {
    final best = game.players.map(value).fold(0, max);
    if (best == 0) return const [];
    return [
      for (final (index, player) in game.players.indexed)
        if (value(player) == best) index,
    ];
  }
}
