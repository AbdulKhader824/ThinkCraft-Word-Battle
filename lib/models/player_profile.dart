/// The player's saved preferences, remembered between games.
class PlayerProfile {
  const PlayerProfile({
    this.name = '',
    this.avatarIndex = 0,
    this.soundOn = true,
  });

  /// How many characters there are to choose from.
  static const avatarCount = 8;

  /// Empty until the player saves a name.
  final String name;
  final int avatarIndex;

  /// Whether sound effects play. On unless the player turns them off.
  final bool soundOn;

  PlayerProfile copyWith({String? name, int? avatarIndex, bool? soundOn}) {
    return PlayerProfile(
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      soundOn: soundOn ?? this.soundOn,
    );
  }
}
