import 'player.dart';

/// The stages of Most Likely To...
enum MostLikelyPhase {
  /// Waiting for friends to join and get ready.
  lobby,

  /// A question is shown, and everyone secretly votes for a player.
  vote,

  /// How many votes each player got, and who is most likely.
  reveal,

  /// The leaderboard after every few questions, with Next Round; after the
  /// last question, the final results.
  results,
}

/// What the questions are about.
enum MostLikelyTopic {
  silly('Silly', '🤪'),
  future('Future', '🚀'),
  adventure('Adventure', '🗺️'),
  everyday('Everyday', '🏠');

  const MostLikelyTopic(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// The host's choices for a Most Likely To... room.
class MostLikelySettings {
  MostLikelySettings({
    this.questions = defaultQuestions,
    Set<MostLikelyTopic>? topics,
  }) : topics = Set.unmodifiable(topics ?? MostLikelyTopic.values.toSet()) {
    if (!questionOptions.contains(questions)) {
      throw ArgumentError.value(questions, 'questions', 'Not an option.');
    }
    if (this.topics.isEmpty) {
      throw ArgumentError.value(topics, 'topics', 'Pick at least one topic.');
    }
  }

  /// Questions in the whole game.
  static const questionOptions = [10, 15, 20];
  static const defaultQuestions = 10;

  /// Questions between leaderboards: a round.
  static const questionsPerRound = 5;

  final int questions;
  final Set<MostLikelyTopic> topics;

  int get rounds => questions ~/ questionsPerRound;
}

/// A Most Likely To... room, as one player may see it.
///
/// The host's phone keeps the whole room. Nobody ever sees who voted for
/// whom, only how many votes each player got, so the game stays kind; and
/// each player sees only their own points until the leaderboard, because
/// points would give votes away.
class MostLikelyRoom {
  MostLikelyRoom({
    required this.code,
    required List<Player> players,
    required this.settings,
    this.capacity = 8,
    this.phase = MostLikelyPhase.lobby,
    this.questionNumber = 0,
    this.topic,
    this.question,
    Map<String, String> votes = const {},
    Set<String> votedIds = const {},
    Map<String, int> voteCounts = const {},
    Set<String> mostLikelyIds = const {},
    Map<String, int> questionPoints = const {},
    Map<String, int> roundPoints = const {},
    Map<String, List<String>> titles = const {},
    this.deadline,
    Set<String> readyIds = const {},
    Set<String> awayIds = const {},
    Map<String, int> scores = const {},
  }) : players = List.unmodifiable(players),
       votes = Map.unmodifiable(votes),
       votedIds = Set.unmodifiable(votedIds),
       voteCounts = Map.unmodifiable(voteCounts),
       mostLikelyIds = Set.unmodifiable(mostLikelyIds),
       questionPoints = Map.unmodifiable(questionPoints),
       roundPoints = Map.unmodifiable(roundPoints),
       titles = Map.unmodifiable({
         for (final MapEntry(:key, :value) in titles.entries)
           key: List<String>.unmodifiable(value),
       }),
       readyIds = Set.unmodifiable(readyIds),
       awayIds = Set.unmodifiable(awayIds),
       scores = Map.unmodifiable(scores);

  final String code;
  final List<Player> players;
  final MostLikelySettings settings;

  /// The most players the room holds.
  final int capacity;
  final MostLikelyPhase phase;

  /// The question being played, from 1 to [MostLikelySettings.questions].
  /// Zero in the first lobby.
  final int questionNumber;

  /// What the question is about.
  final MostLikelyTopic? topic;

  /// The end of the question, such as "become famous", shown as
  /// "Who is most likely to become famous?".
  final String? question;

  /// Who voted for whom, voter first. The host's phone has them all; each
  /// player sees only their own.
  final Map<String, String> votes;

  /// Who has voted, which everyone may see.
  final Set<String> votedIds;

  /// How many votes each player got. Known from the reveal.
  final Map<String, int> voteCounts;

  /// The players with the most votes; more than one on a tie. Empty when
  /// nobody voted.
  final Set<String> mostLikelyIds;

  /// What each player won on this question. Each player sees only their
  /// own.
  final Map<String, int> questionPoints;

  /// What each player has won this round, added to [scores] at the
  /// leaderboard. Each player sees only their own.
  final Map<String, int> roundPoints;

  /// The questions each player was voted most likely for, by player id.
  final Map<String, List<String>> titles;

  /// When the current stage ends.
  final DateTime? deadline;

  /// Players who pressed Next Round.
  final Set<String> readyIds;

  /// Players whose phones lost their connection.
  final Set<String> awayIds;

  /// Points at the last leaderboard, by player id.
  final Map<String, int> scores;

  /// The fewest players a game needs: with two, every vote is obvious.
  static const minPlayers = 3;

  static const voteTime = Duration(seconds: 20);
  static const revealTime = Duration(seconds: 8);
  static const nextRoundWait = Duration(seconds: 60);

  Player get host => players.firstWhere((player) => player.isHost);

  Player? playerOrNull(String? id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  /// The question as players read it.
  String? get questionText =>
      question == null ? null : 'Who is most likely to $question?';

  /// The round being played, from 1: [MostLikelySettings.questionsPerRound]
  /// questions each.
  int get round => questionNumber == 0
      ? 0
      : (questionNumber - 1) ~/ MostLikelySettings.questionsPerRound + 1;

  /// True on the reveal of a round's last question, after which the
  /// leaderboard shows.
  bool get isLastOfRound =>
      questionNumber > 0 &&
      questionNumber % MostLikelySettings.questionsPerRound == 0;

  bool get isFinalRound => round >= settings.rounds;

  /// True on the results after the last question.
  bool get isGameOver => phase == MostLikelyPhase.results && isFinalRound;

  int get emptySeats =>
      capacity > players.length ? capacity - players.length : 0;

  /// True when the host can start: at least 3 players, all ready.
  bool get canStart =>
      players.length >= minPlayers && players.every((player) => player.isReady);

  int scoreOf(String playerId) => scores[playerId] ?? 0;

  /// How long the current stage lasts in all, for the timer ring.
  Duration get stageTime => switch (phase) {
    MostLikelyPhase.vote => voteTime,
    MostLikelyPhase.reveal => revealTime,
    MostLikelyPhase.results => nextRoundWait,
    MostLikelyPhase.lobby => Duration.zero,
  };

  MostLikelyRoom copyWith({
    List<Player>? players,
    MostLikelyPhase? phase,
    int? questionNumber,
    MostLikelyTopic? Function()? topic,
    String? Function()? question,
    Map<String, String>? votes,
    Set<String>? votedIds,
    Map<String, int>? voteCounts,
    Set<String>? mostLikelyIds,
    Map<String, int>? questionPoints,
    Map<String, int>? roundPoints,
    Map<String, List<String>>? titles,
    DateTime? Function()? deadline,
    Set<String>? readyIds,
    Set<String>? awayIds,
    Map<String, int>? scores,
  }) {
    return MostLikelyRoom(
      code: code,
      players: players ?? this.players,
      settings: settings,
      capacity: capacity,
      phase: phase ?? this.phase,
      questionNumber: questionNumber ?? this.questionNumber,
      topic: topic == null ? this.topic : topic(),
      question: question == null ? this.question : question(),
      votes: votes ?? this.votes,
      votedIds: votedIds ?? this.votedIds,
      voteCounts: voteCounts ?? this.voteCounts,
      mostLikelyIds: mostLikelyIds ?? this.mostLikelyIds,
      questionPoints: questionPoints ?? this.questionPoints,
      roundPoints: roundPoints ?? this.roundPoints,
      titles: titles ?? this.titles,
      deadline: deadline == null ? this.deadline : deadline(),
      readyIds: readyIds ?? this.readyIds,
      awayIds: awayIds ?? this.awayIds,
      scores: scores ?? this.scores,
    );
  }
}
