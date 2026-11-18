import '../../models/most_likely_room.dart';

/// Everything Most Likely To...'s screens can ask of a game.
///
/// Screens only use this interface, so they don't know whether this phone
/// is the host or a guest, and tests can use a fake.
abstract interface class MostLikelyService {
  /// The room as this player sees it, or null when not in a game.
  MostLikelyRoom? get room;

  Stream<MostLikelyRoom?> get roomChanges;

  String? get localPlayerId;

  /// Where friends can reach a room this phone hosts, for typing in if it
  /// doesn't show up by itself. Null when not hosting.
  String? get hostAddress;

  /// True in an online room, played through the internet.
  bool get isOnline;

  /// Opens a room on this phone, for friends nearby or, with [online],
  /// anywhere. Throws [JoinRefused] (from game_service.dart) if the
  /// network can't be used.
  Future<void> createRoom({
    required String playerName,
    required int avatarIndex,
    required int capacity,
    required MostLikelySettings settings,
    bool online = false,
  });

  /// Joins a friend's room, nearby or [online]. Throws [JoinRefused] when
  /// it can't.
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  });

  Future<void> setReady(bool isReady);

  /// Only the host can start, once everyone is ready.
  Future<void> startGame();

  /// A secret vote for who is most likely. Players may pick themselves.
  Future<void> vote(String playerId);

  Future<void> nextRound();

  /// Only the host, after the last question.
  Future<void> newGame();

  /// Checks the time again, for when the app returns from the background.
  Future<void> refresh();

  Future<void> leaveRoom();

  void dispose();
}

/// The kinds of message phones send each other in Most Likely To...
abstract final class MostLikelyMessage {
  /// Sent with every greeting, so a phone can't join another game's room.
  static const game = 'most_likely_to';
  static const version = 1;

  // Guest to host.
  static const join = 'join';
  static const rejoin = 'rejoin';
  static const ready = 'ready';
  static const vote = 'vote';
  static const next = 'next';
  static const leave = 'leave';

  // Host to guest.
  static const welcome = 'welcome';
  static const refused = 'refused';
  static const room = 'room';
  static const closed = 'closed';
  static const removed = 'removed';
}
