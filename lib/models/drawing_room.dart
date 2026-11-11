import 'player.dart';

/// The stages of a Guess the Drawing game.
enum DrawingPhase {
  /// Waiting for friends to join and get ready.
  lobby,

  /// The drawer picks one of three words.
  choosing,

  /// The drawer draws, and everyone else guesses.
  drawing,

  /// The word is shown, with the points each player just won.
  turnResult,

  /// The leaderboard after a round, when everyone has drawn once, or at
  /// the end of the game.
  results,
}

/// How hard the words to draw are.
enum WordLevel {
  easy('Easy', 'Simple things, like cat or sun'),
  medium('Medium', 'A bit trickier, like rainbow or robot'),
  hard('Hard', 'For good drawers, like volcano or astronaut'),
  mixed('Mixed', 'A mix of all three');

  const WordLevel(this.label, this.detail);

  final String label;
  final String detail;
}

/// Why a turn ended.
enum TurnEnd {
  /// Every guesser got the word.
  allGuessed,

  /// The time ran out.
  timeUp,

  /// The drawer left or lost their connection.
  drawerLeft,
}

/// The host's choices for a drawing room.
class DrawingSettings {
  DrawingSettings({
    this.rounds = defaultRounds,
    this.drawSeconds = defaultDrawSeconds,
    this.wordLevel = WordLevel.easy,
  }) {
    if (!roundOptions.contains(rounds)) {
      throw ArgumentError.value(rounds, 'rounds', 'Not a round option.');
    }
    if (!drawSecondsOptions.contains(drawSeconds)) {
      throw ArgumentError.value(drawSeconds, 'drawSeconds', 'Not an option.');
    }
  }

  /// In each round, every player draws once.
  static const roundOptions = [1, 2, 3, 5];
  static const defaultRounds = 2;

  static const drawSecondsOptions = [60, 80, 100];
  static const defaultDrawSeconds = 80;

  final int rounds;
  final int drawSeconds;
  final WordLevel wordLevel;

  Duration get drawTime => Duration(seconds: drawSeconds);
}

/// One line in the guess feed under the drawing.
enum FeedKind {
  /// A wrong guess, which everyone sees.
  guess,

  /// Someone got the word. The word itself isn't shown.
  correct,

  /// A guess one letter off. Only the player who typed it sees this.
  close,
}

class FeedEntry {
  const FeedEntry({required this.playerId, required this.kind, this.text = ''});

  final String playerId;
  final FeedKind kind;

  /// The guess, for [FeedKind.guess] and [FeedKind.close].
  final String text;
}

/// A player's running total.
class DrawingScore {
  const DrawingScore({this.points = 0, this.stars = 0});

  final int points;

  /// One for each time they were first to guess.
  final int stars;

  DrawingScore add(int morePoints, {bool star = false}) {
    return DrawingScore(
      points: points + morePoints,
      stars: stars + (star ? 1 : 0),
    );
  }
}

/// A Guess the Drawing room, as one player may see it.
///
/// The host's phone keeps the whole room, and each player gets their own
/// view: only the drawer sees the word choices, and only the drawer and
/// players who have guessed see the word while drawing goes on.
class DrawingRoom {
  DrawingRoom({
    required this.code,
    required List<Player> players,
    required this.settings,
    this.capacity = 8,
    this.phase = DrawingPhase.lobby,
    this.round = 0,
    this.turnId = 0,
    this.turnInRound = 0,
    this.turnsInRound = 0,
    this.drawerId,
    List<String> choices = const [],
    this.word,
    this.wordMask,
    this.deadline,
    List<String> guessedIds = const [],
    List<FeedEntry> feed = const [],
    Map<String, int> turnPoints = const {},
    this.turnEnd,
    Set<String> readyIds = const {},
    Set<String> awayIds = const {},
    Map<String, DrawingScore> scores = const {},
  }) : players = List.unmodifiable(players),
       choices = List.unmodifiable(choices),
       guessedIds = List.unmodifiable(guessedIds),
       feed = List.unmodifiable(feed),
       turnPoints = Map.unmodifiable(turnPoints),
       readyIds = Set.unmodifiable(readyIds),
       awayIds = Set.unmodifiable(awayIds),
       scores = Map.unmodifiable(scores);

  final String code;
  final List<Player> players;
  final DrawingSettings settings;

  /// The most players the room holds.
  final int capacity;
  final DrawingPhase phase;

  /// The round being played, from 1. Zero in the first lobby.
  final int round;

  /// Goes up by one every turn, so drawings from an old turn are ignored.
  final int turnId;

  /// Which turn of this round, from 1, and how many there are.
  final int turnInRound;
  final int turnsInRound;

  /// Whose turn it is to draw.
  final String? drawerId;

  /// The three words to pick from. Only the drawer sees them.
  final List<String> choices;

  /// The word being drawn, for those allowed to see it, and for everyone
  /// once the turn is over.
  final String? word;

  /// The word with unrevealed letters as "_", such as "r_ck_t". Spaces
  /// stay spaces.
  final String? wordMask;

  /// When the current stage ends.
  final DateTime? deadline;

  /// Players who have guessed the word, first first.
  final List<String> guessedIds;

  /// Recent guesses and who got it, oldest first.
  final List<FeedEntry> feed;

  /// What each player won in the turn just ended.
  final Map<String, int> turnPoints;
  final TurnEnd? turnEnd;

  /// Players who pressed Next Round.
  final Set<String> readyIds;

  /// Players whose phones lost their connection.
  final Set<String> awayIds;

  /// Running totals, by player id.
  final Map<String, DrawingScore> scores;

  Player get host => players.firstWhere((player) => player.isHost);

  Player? playerOrNull(String? id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  Player? get drawer => playerOrNull(drawerId);

  int get emptySeats =>
      capacity > players.length ? capacity - players.length : 0;

  /// True when the host can start: at least 2 players, all ready.
  bool get canStart =>
      players.length >= 2 && players.every((player) => player.isReady);

  bool get isFinalRound => round >= settings.rounds;

  /// True on the leaderboard after the last round.
  bool get isGameOver => phase == DrawingPhase.results && isFinalRound;

  DrawingScore scoreOf(String playerId) =>
      scores[playerId] ?? const DrawingScore();

  /// How long the current stage lasts in all, for the timer ring.
  Duration get stageTime => switch (phase) {
    DrawingPhase.choosing => DrawingRoom.chooseTime,
    DrawingPhase.drawing => settings.drawTime,
    DrawingPhase.turnResult => DrawingRoom.turnResultTime,
    DrawingPhase.results => DrawingRoom.nextRoundWait,
    DrawingPhase.lobby => Duration.zero,
  };

  static const chooseTime = Duration(seconds: 15);
  static const turnResultTime = Duration(seconds: 6);
  static const nextRoundWait = Duration(seconds: 60);

  DrawingRoom copyWith({
    List<Player>? players,
    DrawingPhase? phase,
    int? round,
    int? turnId,
    int? turnInRound,
    int? turnsInRound,
    String? Function()? drawerId,
    List<String>? choices,
    String? Function()? word,
    String? Function()? wordMask,
    DateTime? Function()? deadline,
    List<String>? guessedIds,
    List<FeedEntry>? feed,
    Map<String, int>? turnPoints,
    TurnEnd? Function()? turnEnd,
    Set<String>? readyIds,
    Set<String>? awayIds,
    Map<String, DrawingScore>? scores,
  }) {
    return DrawingRoom(
      code: code,
      players: players ?? this.players,
      settings: settings,
      capacity: capacity,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      turnId: turnId ?? this.turnId,
      turnInRound: turnInRound ?? this.turnInRound,
      turnsInRound: turnsInRound ?? this.turnsInRound,
      drawerId: drawerId == null ? this.drawerId : drawerId(),
      choices: choices ?? this.choices,
      word: word == null ? this.word : word(),
      wordMask: wordMask == null ? this.wordMask : wordMask(),
      deadline: deadline == null ? this.deadline : deadline(),
      guessedIds: guessedIds ?? this.guessedIds,
      feed: feed ?? this.feed,
      turnPoints: turnPoints ?? this.turnPoints,
      turnEnd: turnEnd == null ? this.turnEnd : turnEnd(),
      readyIds: readyIds ?? this.readyIds,
      awayIds: awayIds ?? this.awayIds,
      scores: scores ?? this.scores,
    );
  }
}
