import 'player.dart';

/// The stages of one round of The Impostor.
enum ImpostorPhase {
  /// Waiting for friends to join and get ready.
  lobby,

  /// Everyone holds to see the secret word; the Impostor sees only the
  /// topic.
  word,

  /// Players take turns saying a clue out loud.
  clues,

  /// Everyone talks about who the Impostor might be.
  talk,

  /// A secret vote for the Impostor.
  vote,

  /// The votes are shown, then who the Impostor was.
  reveal,

  /// The Impostor picks the word from six.
  guess,

  /// What happened this round and the leaderboard, with Next Round; after
  /// the last round, the final results.
  results,
}

/// What the secret words are about.
enum ImpostorTopic {
  animals('Animals', '🐘'),
  food('Food', '🍕'),
  places('Places', '🏖️'),
  things('Things', '🎒'),
  jobs('Jobs', '👩‍🚒'),
  sports('Sports', '⚽'),
  movies('Movies and cartoons', '🎬');

  const ImpostorTopic(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Why a round ended the way it did.
enum RoundEnd {
  /// The round was played to the end.
  played,

  /// The Impostor left or lost their connection, so nobody scores.
  impostorLeft,
}

/// The host's choices for an Impostor room.
class ImpostorSettings {
  ImpostorSettings({
    this.rounds = defaultRounds,
    this.clueSeconds = defaultClueSeconds,
    this.clueTurns = defaultClueTurns,
    Set<ImpostorTopic>? topics,
  }) : topics = Set.unmodifiable(topics ?? ImpostorTopic.values.toSet()) {
    if (!roundOptions.contains(rounds)) {
      throw ArgumentError.value(rounds, 'rounds', 'Not a round option.');
    }
    if (!clueSecondsOptions.contains(clueSeconds)) {
      throw ArgumentError.value(clueSeconds, 'clueSeconds', 'Not an option.');
    }
    if (!clueTurnsOptions.contains(clueTurns)) {
      throw ArgumentError.value(clueTurns, 'clueTurns', 'Not an option.');
    }
    if (this.topics.isEmpty) {
      throw ArgumentError.value(topics, 'topics', 'Pick at least one topic.');
    }
  }

  /// Each round has a new word and a new Impostor pick.
  static const roundOptions = [3, 5, 8];
  static const defaultRounds = 5;

  static const clueSecondsOptions = [15, 20, 30];
  static const defaultClueSeconds = 20;

  /// How many times each player gives a clue in a round.
  static const clueTurnsOptions = [1, 2];
  static const defaultClueTurns = 2;

  final int rounds;
  final int clueSeconds;
  final int clueTurns;
  final Set<ImpostorTopic> topics;

  Duration get clueTime => Duration(seconds: clueSeconds);
}

/// A player's running totals.
class ImpostorScore {
  const ImpostorScore({
    this.points = 0,
    this.rightVotes = 0,
    this.impostorPoints = 0,
  });

  final int points;

  /// How many times they voted for the Impostor, for Best Detective.
  final int rightVotes;

  /// Points won while they were the Impostor, for Master of Disguise.
  final int impostorPoints;

  ImpostorScore add(
    int morePoints, {
    bool rightVote = false,
    bool asImpostor = false,
  }) {
    return ImpostorScore(
      points: points + morePoints,
      rightVotes: rightVotes + (rightVote ? 1 : 0),
      impostorPoints: impostorPoints + (asImpostor ? morePoints : 0),
    );
  }
}

/// An Impostor room, as one player may see it.
///
/// The host's phone keeps the whole room, and each player gets their own
/// view: the Impostor never sees the word until the round is over, nobody
/// sees who the Impostor is until the reveal, and nobody sees who voted
/// for whom until then either.
class ImpostorRoom {
  ImpostorRoom({
    required this.code,
    required List<Player> players,
    required this.settings,
    this.capacity = 8,
    this.phase = ImpostorPhase.lobby,
    this.round = 0,
    this.topic,
    this.word,
    this.impostorId,
    this.isImpostor = false,
    List<String> clueOrder = const [],
    this.clueIndex = 0,
    Map<String, String> votes = const {},
    Set<String> votedIds = const {},
    List<String> guessChoices = const [],
    this.guessedWord,
    this.caught,
    this.roundEnd,
    Map<String, int> roundPoints = const {},
    this.deadline,
    Set<String> readyIds = const {},
    Set<String> awayIds = const {},
    Map<String, ImpostorScore> scores = const {},
  }) : players = List.unmodifiable(players),
       clueOrder = List.unmodifiable(clueOrder),
       votes = Map.unmodifiable(votes),
       votedIds = Set.unmodifiable(votedIds),
       guessChoices = List.unmodifiable(guessChoices),
       roundPoints = Map.unmodifiable(roundPoints),
       readyIds = Set.unmodifiable(readyIds),
       awayIds = Set.unmodifiable(awayIds),
       scores = Map.unmodifiable(scores);

  final String code;
  final List<Player> players;
  final ImpostorSettings settings;

  /// The most players the room holds.
  final int capacity;
  final ImpostorPhase phase;

  /// The round being played, from 1. Zero in the first lobby.
  final int round;

  /// What this round's word is about. Everyone sees it.
  final ImpostorTopic? topic;

  /// The secret word. Null for the Impostor until the round's results.
  final String? word;

  /// Who the Impostor is. Only the Impostor knows, until the reveal.
  final String? impostorId;

  /// True on the Impostor's own phone.
  final bool isImpostor;

  /// Who gives a clue, in order. With two clue turns, everyone appears
  /// twice.
  final List<String> clueOrder;

  /// Whose clue turn it is, as a place in [clueOrder].
  final int clueIndex;

  /// Who voted for whom, voter first. Each player sees only their own vote
  /// until the reveal.
  final Map<String, String> votes;

  /// Who has voted, which everyone may see.
  final Set<String> votedIds;

  /// The six words the Impostor picks from. Only the Impostor sees them,
  /// while guessing.
  final List<String> guessChoices;

  /// The word the Impostor picked, or null if they ran out of time.
  final String? guessedWord;

  /// Whether the votes caught the Impostor. Known from the reveal.
  final bool? caught;
  final RoundEnd? roundEnd;

  /// What each player won this round.
  final Map<String, int> roundPoints;

  /// When the current stage ends.
  final DateTime? deadline;

  /// Players who pressed Next Round.
  final Set<String> readyIds;

  /// Players whose phones lost their connection.
  final Set<String> awayIds;

  /// Running totals, by player id.
  final Map<String, ImpostorScore> scores;

  /// The fewest players a game needs: with two, the only voter would know.
  static const minPlayers = 3;

  Player get host => players.firstWhere((player) => player.isHost);

  Player? playerOrNull(String? id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  Player? get impostor => playerOrNull(impostorId);

  /// The player giving a clue now.
  String? get speakerId =>
      phase == ImpostorPhase.clues && clueIndex < clueOrder.length
      ? clueOrder[clueIndex]
      : null;

  int get emptySeats =>
      capacity > players.length ? capacity - players.length : 0;

  /// True when the host can start: at least 3 players, all ready.
  bool get canStart =>
      players.length >= minPlayers && players.every((player) => player.isReady);

  bool get isFinalRound => round >= settings.rounds;

  /// True on the results after the last round.
  bool get isGameOver => phase == ImpostorPhase.results && isFinalRound;

  /// True when the Impostor picked the right word.
  bool get guessedRight =>
      guessedWord != null && word != null && guessedWord == word;

  ImpostorScore scoreOf(String playerId) =>
      scores[playerId] ?? const ImpostorScore();

  /// How long the current stage lasts in all, for the timer ring.
  Duration get stageTime => switch (phase) {
    ImpostorPhase.word => wordTime,
    ImpostorPhase.clues => settings.clueTime,
    ImpostorPhase.talk => talkTime,
    ImpostorPhase.vote => voteTime,
    ImpostorPhase.reveal => revealTime,
    ImpostorPhase.guess => guessTime,
    ImpostorPhase.results => nextRoundWait,
    ImpostorPhase.lobby => Duration.zero,
  };

  static const wordTime = Duration(seconds: 10);
  static const talkTime = Duration(seconds: 30);
  static const voteTime = Duration(seconds: 20);
  static const revealTime = Duration(seconds: 8);
  static const guessTime = Duration(seconds: 15);
  static const nextRoundWait = Duration(seconds: 60);

  ImpostorRoom copyWith({
    List<Player>? players,
    ImpostorPhase? phase,
    int? round,
    ImpostorTopic? Function()? topic,
    String? Function()? word,
    String? Function()? impostorId,
    bool? isImpostor,
    List<String>? clueOrder,
    int? clueIndex,
    Map<String, String>? votes,
    Set<String>? votedIds,
    List<String>? guessChoices,
    String? Function()? guessedWord,
    bool? Function()? caught,
    RoundEnd? Function()? roundEnd,
    Map<String, int>? roundPoints,
    DateTime? Function()? deadline,
    Set<String>? readyIds,
    Set<String>? awayIds,
    Map<String, ImpostorScore>? scores,
  }) {
    return ImpostorRoom(
      code: code,
      players: players ?? this.players,
      settings: settings,
      capacity: capacity,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      topic: topic == null ? this.topic : topic(),
      word: word == null ? this.word : word(),
      impostorId: impostorId == null ? this.impostorId : impostorId(),
      isImpostor: isImpostor ?? this.isImpostor,
      clueOrder: clueOrder ?? this.clueOrder,
      clueIndex: clueIndex ?? this.clueIndex,
      votes: votes ?? this.votes,
      votedIds: votedIds ?? this.votedIds,
      guessChoices: guessChoices ?? this.guessChoices,
      guessedWord: guessedWord == null ? this.guessedWord : guessedWord(),
      caught: caught == null ? this.caught : caught(),
      roundEnd: roundEnd == null ? this.roundEnd : roundEnd(),
      roundPoints: roundPoints ?? this.roundPoints,
      deadline: deadline == null ? this.deadline : deadline(),
      readyIds: readyIds ?? this.readyIds,
      awayIds: awayIds ?? this.awayIds,
      scores: scores ?? this.scores,
    );
  }
}
