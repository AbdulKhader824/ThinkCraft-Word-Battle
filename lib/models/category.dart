/// The kinds of answer a round can ask for. The host picks which ones a
/// room plays on Create Room.
///
/// The order here is the order they appear in everywhere: on Create Room,
/// in the lobby and on the answer screen. Names are saved and sent between
/// phones, so a name must never change.
enum Category {
  animal('Animal'),
  bird('Bird'),
  place('Place'),
  person('Person Name'),
  celebrity('Celebrity'),
  movie('Movie'),
  cartoon('Cartoon'),
  food('Food'),
  vegetable('Vegetable'),
  flower('Flower'),
  thing('Thing'),
  vehicle('Vehicle'),
  sport('Sport'),
  game('Game'),
  brand('Brand');

  const Category(this.label);

  final String label;

  /// The classic six: the standard game, used when a room doesn't say
  /// otherwise (such as a practice room's bot host). They have the biggest
  /// word lists and bot word banks.
  static const defaults = [animal, place, person, movie, food, brand];

  /// What Create Room has picked to start with. Rounds with many more take
  /// a long time to answer and vote on.
  static const startingPicks = [animal, bird, place, person];

  /// Categories whose answers can also be right for this one: an eagle is
  /// a bird and an animal. Bots never give one of these as a deliberately
  /// wrong answer, because it might not be wrong.
  Set<Category> get related => switch (this) {
    animal || bird => const {animal, bird},
    person || celebrity => const {person, celebrity},
    movie || cartoon => const {movie, cartoon},
    food || vegetable => const {food, vegetable},
    sport || game => const {sport, game},
    brand || vehicle => const {brand, vehicle},
    _ => {this},
  };
}
