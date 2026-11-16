import '../../models/impostor_room.dart';

/// Everything The Impostor's screens can ask of a game.
///
/// Screens only use this interface, so they don't know whether this phone
/// is the host or a guest, and tests can use a fake.
abstract interface class ImpostorService {
  /// The room as this player sees it, or null when not in a game.
  ImpostorRoom? get room;

  Stream<ImpostorRoom?> get roomChanges;

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
    required ImpostorSettings settings,
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

  /// The speaker has said their clue.
  Future<void> clueDone();

  /// Only the host: stop talking and vote.
  Future<void> voteNow();

  /// A secret vote for who the Impostor is.
  Future<void> vote(String suspectId);

  /// The Impostor picks the word.
  Future<void> guessWord(String word);

  Future<void> nextRound();

  /// Only the host, after the last round.
  Future<void> newGame();

  /// Checks the time again, for when the app returns from the background.
  Future<void> refresh();

  Future<void> leaveRoom();

  void dispose();
}

/// The kinds of message phones send each other in The Impostor.
abstract final class ImpostorMessage {
  /// Sent with every greeting, so a phone can't join another game's room.
  static const game = 'the_impostor';
  static const version = 1;

  // Guest to host.
  static const join = 'join';
  static const rejoin = 'rejoin';
  static const ready = 'ready';
  static const done = 'done';
  static const vote = 'vote';
  static const guess = 'guess';
  static const next = 'next';
  static const leave = 'leave';

  // Host to guest.
  static const welcome = 'welcome';
  static const refused = 'refused';
  static const room = 'room';
  static const closed = 'closed';
  static const removed = 'removed';
}
