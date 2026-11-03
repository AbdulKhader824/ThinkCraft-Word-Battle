/// The player's saved name and character, remembered between games.
class PlayerProfile {
  const PlayerProfile({this.name = '', this.avatarIndex = 0});

  /// How many characters there are to choose from.
  static const avatarCount = 8;

  /// Empty until the player saves a name.
  final String name;
  final int avatarIndex;

  PlayerProfile copyWith({String? name, int? avatarIndex}) {
    return PlayerProfile(
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }
}
