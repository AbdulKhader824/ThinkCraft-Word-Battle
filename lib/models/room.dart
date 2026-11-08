import 'game_phase.dart';
import 'game_settings.dart';
import 'player.dart';
import 'round.dart';
import 'round_results.dart';

/// Where the other players are.
enum RoomMode {
  /// Just this player and simulated bots, on this phone.
  practice,

  /// Friends on the same Wi-Fi or this phone's hotspot. The host's phone
  /// runs the game.
  nearby,

  /// Friends anywhere, through the internet. Not built yet.
  online,
}

/// A game room. Rooms are never changed in place: every change makes a new
/// copy with [copyWith], so a half-updated room can't reach the screen.
class Room {
  Room({
    required this.code,
    required List<Player> players,
    GameSettings? settings,
    this.mode = RoomMode.practice,
    this.capacity = 8,
    this.fillWithBots = false,
    this.phase = GamePhase.lobby,
    this.round,
    Set<String> usedLetters = const {},
    Map<String, ScoreLine> scores = const {},
  }) : settings = settings ?? GameSettings.standard,
       players = List.unmodifiable(players),
       usedLetters = Set.unmodifiable(usedLetters),
       scores = Map.unmodifiable(scores);

  final String code;
  final List<Player> players;

  /// The rounds and categories chosen by the host.
  final GameSettings settings;
  final RoomMode mode;

  /// The most players the room holds, chosen by the host. Friends can't
  /// join once it is full.
  final int capacity;

  /// When true, seats nobody has taken are given to bots as the game
  /// starts. When false, the game is just the players who joined.
  final bool fillWithBots;

  final GamePhase phase;

  /// Seats nobody has taken yet.
  int get emptySeats =>
      capacity > players.length ? capacity - players.length : 0;

  /// The current round. Null while in the first lobby.
  final Round? round;

  /// Letters already played in this game.
  final Set<String> usedLetters;

  /// Running totals across every round, by player id.
  final Map<String, ScoreLine> scores;

  List<String> get playerIds => [for (final player in players) player.id];

  Player get host => players.firstWhere((player) => player.isHost);

  Player playerById(String id) {
    return players.firstWhere((player) => player.id == id);
  }

  /// True when the host can start: enough players, all of them ready.
  /// With bots filling the empty seats, the host can start alone.
  bool get canStart {
    final enough = players.length >= 2 || (fillWithBots && emptySeats > 0);
    return enough && players.every((player) => player.isReady);
  }

  /// True during the game's last round.
  bool get isFinalRound {
    final number = round?.number;
    return number != null && number >= settings.rounds;
  }

  Room copyWith({
    List<Player>? players,
    GamePhase? phase,
    Round? round,
    Set<String>? usedLetters,
    Map<String, ScoreLine>? scores,
  }) {
    return Room(
      code: code,
      players: players ?? this.players,
      settings: settings,
      mode: mode,
      capacity: capacity,
      fillWithBots: fillWithBots,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      usedLetters: usedLetters ?? this.usedLetters,
      scores: scores ?? this.scores,
    );
  }
}
