import 'answer.dart';
import 'answer_group.dart';
import 'round_results.dart';
import 'vote.dart';

/// One round of play, as this player is allowed to see it.
///
/// [answers] stays empty until results, so no player's device holds who
/// wrote what while the round or the voting is running.
class Round {
  Round({
    required this.number,
    required this.pickerId,
    this.letter,
    this.deadline,
    Set<String> submittedPlayerIds = const {},
    List<Answer> answers = const [],
    List<BallotItem> ballot = const [],
    Map<String, VoteChoice> myVotes = const {},
    this.results,
  }) : submittedPlayerIds = Set.unmodifiable(submittedPlayerIds),
       answers = List.unmodifiable(answers),
       ballot = List.unmodifiable(ballot),
       myVotes = Map.unmodifiable(myVotes);

  final int number;

  /// The player choosing this round's letter.
  final String pickerId;

  /// Null until the letter is chosen.
  final String? letter;

  /// When the answer timer ends. Null until answering starts.
  final DateTime? deadline;

  final Set<String> submittedPlayerIds;

  /// Everyone's answers. Empty until results.
  final List<Answer> answers;

  /// The anonymous answers this player can vote on.
  final List<BallotItem> ballot;

  /// This player's choices so far, by ballot item id.
  final Map<String, VoteChoice> myVotes;

  /// Null until the votes are counted.
  final RoundResults? results;

  /// The next answer to vote on, or null when finished.
  BallotItem? get nextBallotItem {
    for (final item in ballot) {
      if (!myVotes.containsKey(item.id)) return item;
    }
    return null;
  }

  Round copyWith({
    String? letter,
    DateTime? deadline,
    Set<String>? submittedPlayerIds,
    List<Answer>? answers,
    List<BallotItem>? ballot,
    Map<String, VoteChoice>? myVotes,
    RoundResults? results,
  }) {
    return Round(
      number: number,
      pickerId: pickerId,
      letter: letter ?? this.letter,
      deadline: deadline ?? this.deadline,
      submittedPlayerIds: submittedPlayerIds ?? this.submittedPlayerIds,
      answers: answers ?? this.answers,
      ballot: ballot ?? this.ballot,
      myVotes: myVotes ?? this.myVotes,
      results: results ?? this.results,
    );
  }
}
