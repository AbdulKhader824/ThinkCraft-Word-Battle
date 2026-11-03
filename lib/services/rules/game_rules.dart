/// Rules for rounds and answers. Plain Dart, with no Flutter imports.
abstract final class GameRules {
  static const answerTime = Duration(seconds: 90);

  static final letters = List<String>.unmodifiable(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''),
  );

  /// True when [text] begins with [letter], ignoring capitals and spaces.
  /// Blank answers return true, because they are empty rather than wrong.
  static bool startsWithLetter(String text, String letter) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    return trimmed.toUpperCase().startsWith(letter.toUpperCase());
  }
}
