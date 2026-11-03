import '../../models/answer.dart';
import '../../models/answer_group.dart';
import 'game_rules.dart';

/// Gathers identical answers together. Plain Dart, with no Flutter imports.
abstract final class AnswerRules {
  static final _extraSpaces = RegExp(r'\s+');

  /// Tidies text for showing: no spaces at the ends or repeated inside.
  static String tidy(String text) {
    return text.trim().replaceAll(_extraSpaces, ' ');
  }

  /// The form used to compare answers: tidied, ignoring capitals.
  static String normalize(String text) => tidy(text).toLowerCase();

  /// The id of the group an answer belongs to.
  static String groupIdFor(Answer answer) {
    return '${answer.category.name}:${normalize(answer.text)}';
  }

  /// Groups [answers] and decides any that need no vote: a wrong starting
  /// letter is invalid, and an answer everyone shares is valid because
  /// nobody is left to vote on it. Empty answers are left out.
  static List<AnswerGroup> groupAnswers({
    required List<Answer> answers,
    required String letter,
    required List<String> playerIds,
  }) {
    final grouped = <String, List<Answer>>{};
    for (final answer in answers.where((answer) => !answer.isEmpty)) {
      grouped.putIfAbsent(groupIdFor(answer), () => []).add(answer);
    }

    return [
      for (final MapEntry(key: id, value: members) in grouped.entries)
        _buildGroup(id, members, letter, playerIds),
    ];
  }

  static AnswerGroup _buildGroup(
    String id,
    List<Answer> members,
    String letter,
    List<String> playerIds,
  ) {
    final first = members.first;
    final authors = {for (final member in members) member.playerId};

    return AnswerGroup(
      id: id,
      category: first.category,
      text: tidy(first.text),
      authorIds: authors,
      autoVerdict: _autoVerdict(first.text, letter, authors, playerIds),
    );
  }

  static AnswerVerdict? _autoVerdict(
    String text,
    String letter,
    Set<String> authors,
    List<String> playerIds,
  ) {
    if (!GameRules.startsWithLetter(text, letter)) {
      return AnswerVerdict.invalid;
    }
    return authors.containsAll(playerIds) ? AnswerVerdict.valid : null;
  }
}
