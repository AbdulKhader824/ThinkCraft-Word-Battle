// Truth or Dare, played on one phone passed around the group.

/// Which cards are used.
enum TodLevel {
  kids('Kids', 'Silly and gentle'),
  teens('Teens', 'A bit cheekier, still clean'),
  mix('Mix', 'Kids and Teens cards together');

  const TodLevel(this.label, this.detail);

  final String label;
  final String detail;
}

enum TodKind {
  truth('Truth'),
  dare('Dare');

  const TodKind(this.label);

  final String label;
}

/// The stages of a turn.
enum TodPhase {
  /// The spinner picks whose turn it is.
  spin,

  /// The player picks Truth or Dare.
  choose,

  /// The card is shown; the group decides Done or Skip.
  card,

  /// The game is over.
  finished,
}

/// The group's choices before playing.
class TodSettings {
  TodSettings({this.rounds = defaultRounds, this.level = TodLevel.kids}) {
    if (!roundOptions.contains(rounds)) {
      throw ArgumentError.value(rounds, 'rounds', 'Not an option.');
    }
  }

  /// In a round, everyone still in has one turn.
  static const roundOptions = [3, 5, 10];
  static const defaultRounds = 5;

  final int rounds;
  final TodLevel level;
}

/// One player at the table, with how they've done.
class TodPlayer {
  const TodPlayer({
    required this.name,
    required this.avatarIndex,
    this.truths = 0,
    this.dares = 0,
    this.skips = 0,
  });

  final String name;
  final int avatarIndex;

  /// Truths answered and dares done.
  final int truths;
  final int dares;

  /// Cards skipped. Each one costs a life.
  final int skips;

  /// Every player starts with this many lives.
  static const lives = 3;

  int get livesLeft => skips >= lives ? 0 : lives - skips;

  /// Out of the game after skipping [lives] times.
  bool get isOut => livesLeft == 0;

  /// A point for every truth answered and dare done.
  int get points => truths + dares;

  TodPlayer copyWith({int? truths, int? dares, int? skips}) => TodPlayer(
    name: name,
    avatarIndex: avatarIndex,
    truths: truths ?? this.truths,
    dares: dares ?? this.dares,
    skips: skips ?? this.skips,
  );
}

/// A game of Truth or Dare.
class TodGame {
  TodGame({
    required List<TodPlayer> players,
    required this.settings,
    this.phase = TodPhase.spin,
    this.round = 1,
    Set<int> takenThisRound = const {},
    this.current,
    this.previous,
    this.kind,
    this.card,
    Set<String> usedCards = const {},
  }) : players = List.unmodifiable(players),
       takenThisRound = Set.unmodifiable(takenThisRound),
       usedCards = Set.unmodifiable(usedCards);

  final List<TodPlayer> players;
  final TodSettings settings;
  final TodPhase phase;

  /// The round being played, from 1.
  final int round;

  /// Players (by place in [players]) who have had their turn this round.
  final Set<int> takenThisRound;

  /// Whose turn it is, by place in [players].
  final int? current;

  /// Whose turn it was before, so nobody goes twice in a row.
  final int? previous;

  /// Truth or Dare, once picked.
  final TodKind? kind;

  /// The card being played.
  final String? card;

  /// Cards already played, so they don't come up again.
  final Set<String> usedCards;

  static const minPlayers = 2;
  static const maxPlayers = 12;

  TodPlayer? get currentPlayer => current == null ? null : players[current!];

  /// Players who haven't run out of lives, by place in [players].
  List<int> get stillIn => [
    for (final (index, player) in players.indexed)
      if (!player.isOut) index,
  ];

  TodGame copyWith({
    List<TodPlayer>? players,
    TodPhase? phase,
    int? round,
    Set<int>? takenThisRound,
    int? Function()? current,
    int? Function()? previous,
    TodKind? Function()? kind,
    String? Function()? card,
    Set<String>? usedCards,
  }) {
    return TodGame(
      players: players ?? this.players,
      settings: settings,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      takenThisRound: takenThisRound ?? this.takenThisRound,
      current: current == null ? this.current : current(),
      previous: previous == null ? this.previous : previous(),
      kind: kind == null ? this.kind : kind(),
      card: card == null ? this.card : card(),
      usedCards: usedCards ?? this.usedCards,
    );
  }
}
