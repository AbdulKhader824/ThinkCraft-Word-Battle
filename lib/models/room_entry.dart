/// What a player chose on the Create Room or Join Room screen.
class RoomEntry {
  const RoomEntry.create({
    required this.playerName,
    required int this.playerCount,
  }) : roomCode = null;

  const RoomEntry.join({
    required this.playerName,
    required String this.roomCode,
  }) : playerCount = null;

  final String playerName;

  /// Set when creating a room.
  final int? playerCount;

  /// Set when joining a room.
  final String? roomCode;
}
