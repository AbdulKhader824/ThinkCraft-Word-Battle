/// What a player can choose for an answer on the ballot.
enum VoteChoice { valid, invalid, skip }

/// One counted vote. Skipped answers don't create a vote.
class Vote {
  const Vote({
    required this.voterId,
    required this.groupId,
    required this.isValid,
  });

  final String voterId;
  final String groupId;
  final bool isValid;
}
