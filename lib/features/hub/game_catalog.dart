/// Every game in PlayPals, in the order the hub shows them.
///
/// A game becomes playable by giving it a [GameInfo.route]. Until then the
/// hub shows it as Coming soon.
library;

/// What a game needs to be played.
enum GameDevices {
  /// Everyone plays on their own phone, in a shared room.
  everyPhone('Every player uses their phone'),

  /// The group shares one phone, so there's no room to make.
  onePhone('Just one phone needed');

  const GameDevices(this.label);

  final String label;
}

/// One game card in the hub.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.devices,
    this.route,
  });

  /// Also names the card picture, `assets/images/games/<id>.webp`.
  final String id;
  final String name;

  /// One short line about how the game plays.
  final String tagline;
  final GameDevices devices;

  /// Where Play goes. Null while the game is still being made.
  final String? route;

  bool get isPlayable => route != null;

  String get picture => 'assets/images/games/$id.webp';
}

abstract final class GameCatalog {
  static const wordBattleRoute = '/word-battle';

  static const games = [
    GameInfo(
      id: 'word_battle',
      name: 'Word Battle',
      tagline: 'A letter drops. Find a name, place, animal and more, fast!',
      devices: GameDevices.everyPhone,
      route: wordBattleRoute,
    ),
    GameInfo(
      id: 'guess_the_drawing',
      name: 'Guess the Drawing',
      tagline: 'One player draws, and everyone races to guess it.',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'card_game',
      name: 'Colour Rush',
      tagline: 'Match colours and numbers. Skip, reverse and draw!',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'ludo',
      name: 'Ludo',
      tagline: 'Roll the dice, race your tokens home and cut others.',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'the_impostor',
      name: 'The Impostor',
      tagline: 'Everyone knows the secret word except one. Who is it?',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'most_likely_to',
      name: 'Most Likely To...',
      tagline: 'Vote for who fits each funny question best.',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'two_truths_one_lie',
      name: 'Two Truths, One Lie',
      tagline: 'Share three facts about you. Can they spot the fake?',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'tap_tug_of_war',
      name: 'Tap Tug-of-War',
      tagline: 'Tap as fast as you can to pull the rope to your side!',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'truth_or_dare',
      name: 'Truth or Dare',
      tagline: 'Spin to pick a player, then answer a truth or do a dare.',
      devices: GameDevices.onePhone,
    ),
    GameInfo(
      id: 'pass_the_bomb',
      name: 'Pass the Bomb',
      tagline: 'Solve a quick puzzle to pass the bomb before it pops!',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'bluff_it',
      name: 'Bluff It',
      tagline: 'Write fake answers to fool friends, then find the real one.',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'dumb_charades',
      name: 'Dumb Charades',
      tagline: 'Act out Malayalam movie titles before time runs out.',
      devices: GameDevices.onePhone,
    ),
    GameInfo(
      id: 'complete_the_lyrics',
      name: 'Complete the Lyrics',
      tagline: 'Sing the missing line of the song before the timer ends.',
      devices: GameDevices.onePhone,
    ),
    GameInfo(
      id: 'turtle_elephant_goat',
      name: 'Turtle Elephant Goat',
      tagline: 'Pass cards around. Three of a kind? Tap first to win!',
      devices: GameDevices.everyPhone,
    ),
    GameInfo(
      id: 'who_am_i',
      name: 'Who Am I?',
      tagline: 'Hold the phone to your head and ask questions to guess.',
      devices: GameDevices.onePhone,
    ),
  ];
}
