import 'category.dart';

/// One player's locked answer for one category. Blank means no answer.
class Answer {
  const Answer({
    required this.playerId,
    required this.category,
    required this.text,
  });

  final String playerId;
  final Category category;
  final String text;

  bool get isEmpty => text.trim().isEmpty;
}
