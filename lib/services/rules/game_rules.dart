/// Rules for rounds and answers. Plain Dart, with no Flutter imports.
abstract final class GameRules {
  /// The standard answer timer. Rooms can choose a shorter one, which is
  /// in `GameSettings.answerTime`.
  static const answerTime = Duration(seconds: 90);

  /// How long the results wait for everyone to press Next Round. Players
  /// who haven't by then leave the room.
  static const nextRoundWait = Duration(seconds: 60);

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
