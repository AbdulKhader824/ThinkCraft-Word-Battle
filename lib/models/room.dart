import 'game_phase.dart';
import 'player.dart';
import 'round.dart';
import 'round_results.dart';

/// A game room. Rooms are never changed in place: every change makes a new
/// copy with [copyWith], so a half-updated room can't reach the screen.
class Room {
  Room({
    required this.code,
    required List<Player> players,
    this.phase = GamePhase.lobby,
    this.round,
    Set<String> usedLetters = const {},
    Map<String, ScoreLine> scores = const {},
  }) : players = List.unmodifiable(players),
       usedLetters = Set.unmodifiable(usedLetters),
       scores = Map.unmodifiable(scores);

  final String code;
  final List<Player> players;
  final GamePhase phase;

  /// The current round. Null while in the first lobby.
  final Round? round;

  /// Letters already played in this room.
  final Set<String> usedLetters;

  /// Running totals across every round, by player id.
  final Map<String, ScoreLine> scores;

  List<String> get playerIds => [for (final player in players) player.id];

  Player get host => players.firstWhere((player) => player.isHost);

  Player playerById(String id) {
    return players.firstWhere((player) => player.id == id);
  }

  /// True when the host can start: enough players, all of them ready.
  bool get canStart {
    return players.length >= 2 && players.every((player) => player.isReady);
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
      phase: phase ?? this.phase,
      round: round ?? this.round,
      usedLetters: usedLetters ?? this.usedLetters,
      scores: scores ?? this.scores,
    );
  }
}
