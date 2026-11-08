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
    this.checkedByWordList = false,
  }) : authorIds = Set.unmodifiable(authorIds);

  final String id;
  final Category category;
  final String text;
  final Set<String> authorIds;

  /// Set when the outcome is known without a vote.
  final AnswerVerdict? autoVerdict;

  /// True when the word list decided [autoVerdict].
  final bool checkedByWordList;

  bool get needsVote => autoVerdict == null;

  /// This group, decided by the word list instead of a vote.
  AnswerGroup settledByWordList(AnswerVerdict verdict) => AnswerGroup(
    id: id,
    category: category,
    text: text,
    authorIds: authorIds,
    autoVerdict: verdict,
    checkedByWordList: true,
  );
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
