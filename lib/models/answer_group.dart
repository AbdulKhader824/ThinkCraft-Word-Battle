import 'category.dart';

/// The outcome for an answer.
enum AnswerVerdict { valid, invalid, disputed }

/// Identical answers in one category, gathered together.
///
/// This knows who wrote each answer, so it stays inside the game service
/// until results. Players vote on a [BallotItem] instead.
class AnswerGroup {
  AnswerGroup({
    required this.id,
    required this.category,
    required this.text,
    required Set<String> authorIds,
    this.autoVerdict,
  }) : authorIds = Set.unmodifiable(authorIds);

  final String id;
  final Category category;
  final String text;
  final Set<String> authorIds;

  /// Set when the outcome is known without a vote.
  final AnswerVerdict? autoVerdict;

  bool get needsVote => autoVerdict == null;
}

/// An answer as voters see it: no player identities at all.
class BallotItem {
  const BallotItem({
    required this.id,
    required this.category,
    required this.text,
  });

  final String id;
  final Category category;
  final String text;
}
