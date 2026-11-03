import 'answer.dart';

/// One round of play.
///
/// [answers] stays empty until everyone has locked in, so no player's screen
/// ever holds another player's answers while the round is running.
class Round {
  Round({
    required this.number,
    required this.pickerId,
    this.letter,
    this.deadline,
    Set<String> submittedPlayerIds = const {},
    List<Answer> answers = const [],
  }) : submittedPlayerIds = Set.unmodifiable(submittedPlayerIds),
       answers = List.unmodifiable(answers);

  final int number;

  /// The player choosing this round's letter.
  final String pickerId;

  /// Null until the letter is chosen.
  final String? letter;

  /// When the answer timer ends. Null until answering starts.
  final DateTime? deadline;

  final Set<String> submittedPlayerIds;
  final List<Answer> answers;

  Round copyWith({
    String? letter,
    DateTime? deadline,
    Set<String>? submittedPlayerIds,
    List<Answer>? answers,
  }) {
    return Round(
      number: number,
      pickerId: pickerId,
      letter: letter ?? this.letter,
      deadline: deadline ?? this.deadline,
      submittedPlayerIds: submittedPlayerIds ?? this.submittedPlayerIds,
      answers: answers ?? this.answers,
    );
  }
}
