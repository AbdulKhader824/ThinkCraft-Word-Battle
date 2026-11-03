import '../../models/answer_group.dart';
import '../../models/vote.dart';

/// Who may vote, and what the votes decide. Plain Dart.
abstract final class VoteRules {
  /// True when [voterId] may vote on [group]: it needs a vote, and they
  /// didn't write it.
  static bool canVote(AnswerGroup group, String voterId) {
    return group.needsVote && !group.authorIds.contains(voterId);
  }

  /// Returns [votes] with [vote] added. Throws for a vote on your own answer
  /// or a second vote on the same answer.
  static List<Vote> addVote(List<Vote> votes, Vote vote, AnswerGroup group) {
    if (!canVote(group, vote.voterId)) {
      throw StateError('This player cannot vote on this answer.');
    }
    final isDuplicate = votes.any(
      (other) => other.voterId == vote.voterId && other.groupId == vote.groupId,
    );
    if (isDuplicate) throw StateError('This player has already voted.');

    return [...votes, vote];
  }

  /// The outcome for [group]. An automatic verdict always wins; otherwise
  /// the majority decides, and a tie (including no votes) is disputed.
  static AnswerVerdict verdictFor(AnswerGroup group, List<Vote> votes) {
    final automatic = group.autoVerdict;
    if (automatic != null) return automatic;

    final counted = votes.where((vote) => vote.groupId == group.id);
    final valid = counted.where((vote) => vote.isValid).length;
    final invalid = counted.length - valid;

    if (valid == invalid) return AnswerVerdict.disputed;
    return valid > invalid ? AnswerVerdict.valid : AnswerVerdict.invalid;
  }
}
