/// The six categories in every round.
enum Category {
  animal('Animal'),
  place('Place'),
  person('Person Name'),
  movie('Movie'),
  food('Food'),
  brand('Brand');

  const Category(this.label);

  final String label;
}
