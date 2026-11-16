import '../models/category.dart';
import '../models/game_settings.dart';
import '../models/room.dart';
import '../models/vote.dart';
import 'rules/game_rules.dart';

/// Why a player couldn't join a room, in words to show them.
class JoinRefused implements Exception {
  const JoinRefused(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the screens can ask of a game.
///
/// Screens depend only on this interface. [LocalGameService] simulates the
/// other players today, and a SignalR version can replace it later without
/// changing any screen. Actions return a Future because a real server takes
/// time to answer.
abstract interface class GameService {
  /// The current room, or null when not in a game.
  Room? get room;

  /// Announces every change to [room].
  Stream<Room?> get roomChanges;

  /// The id of the person using this device.
  String? get localPlayerId;

  /// [avatarIndex] is the player's chosen character; bots get the others.
  /// [settings] are the rounds and categories, chosen by the host.
  /// [mode] says where the friends are. [playerCount] only counts in
  /// practice, where it sets how many bots play.
  Future<void> createRoom({
    required String playerName,
    required int playerCount,
    int avatarIndex = 0,
    GameSettings? settings,
    RoomMode mode = RoomMode.practice,
    bool fillWithBots = false,
  });

  /// Joins a friend's room by its code. [hostAddress] is the host phone's
  /// network address, for when the room can't be found automatically.
  /// [online] joins through the internet instead of Wi-Fi.
  /// Throws [JoinRefused] when the room can't be joined.
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  });

  /// Marks the local player as ready or not. Hosts are always ready.
  Future<void> setReady(bool isReady);

  /// Starts a round. Only the host can do this, once everyone is ready.
  Future<void> startRound();

  /// Chooses the round's letter. Only the round's picker can do this.
  Future<void> selectLetter(String letter);

  /// Saves what is typed so far, so the timer can lock it. Ignored once the
  /// player's answers are locked.
  Future<void> updateAnswer(Category category, String text);

  /// Locks the local player's answers early. Ignored if already locked.
  Future<void> submitAnswers();

  /// Records the local player's choice for a ballot item. Each item takes
  /// one choice only.
  Future<void> castVote(String ballotItemId, VoteChoice choice);

  /// Says the local player is ready for the next round. The round starts,
  /// keeping the running totals, once everyone is ready, or when
  /// [GameRules.nextRoundWait] runs out, with only the players who are
  /// ready; the others leave the room. Not allowed after the final round.
  Future<void> nextRound();

  /// Starts again from round 1 with the same players and settings, clearing
  /// the scores and used letters.
  Future<void> newGame();

  /// Checks the time again, for when the app returns from the background.
  Future<void> refresh();

  /// Leaves the game, clearing the room and its scores.
  Future<void> leaveRoom();

  void dispose();
}
