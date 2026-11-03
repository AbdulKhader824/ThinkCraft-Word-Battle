/// Someone in a room, either the person on this device or a simulated bot.
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.avatarIndex,
    this.isHost = false,
    this.isBot = false,
    this.isReady = false,
  });

  final String id;
  final String name;
  final int avatarIndex;
  final bool isHost;
  final bool isBot;
  final bool isReady;

  Player copyWith({bool? isReady}) {
    return Player(
      id: id,
      name: name,
      avatarIndex: avatarIndex,
      isHost: isHost,
      isBot: isBot,
      isReady: isReady ?? this.isReady,
    );
  }
}
