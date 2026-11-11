import 'word_check.dart';

/// The rules of Guess the Drawing: points, checking guesses and hints.
abstract final class DrawingRules {
  /// Points for guessing the word, by order: first, second, third... Later
  /// guessers all get the last amount.
  static const guessPoints = [10, 8, 6, 5, 4, 3];

  /// The drawer's points for each player who guesses the word.
  static const drawerPointsPerGuess = 3;

  /// The drawer's bonus when every guesser gets it.
  static const everyoneGuessedBonus = 2;

  /// Guesses longer than this are cut short.
  static const maxGuessLength = 30;

  /// How many guesses the feed keeps.
  static const feedLength = 30;

  /// Points for the player who guessed [order]th, counting from 0.
  static int pointsForGuess(int order) {
    return guessPoints[order.clamp(0, guessPoints.length - 1)];
  }

  /// The drawer's points, when [guessed] of [guessers] got the word.
  static int drawerPoints({required int guessed, required int guessers}) {
    if (guessed == 0) return 0;
    final everyone = guessed >= guessers;
    return guessed * drawerPointsPerGuess +
        (everyone ? everyoneGuessedBonus : 0);
  }

  /// The form a guess is compared in: capitals, spaces, punctuation and
  /// British or American spelling don't matter.
  static String _key(String text) => WordCheck.keyFor(text);

  /// True when [guess] is [word], allowing for capitals, extra spaces and
  /// plurals, so "Cats" counts for "cat".
  static bool isCorrect(String guess, String word) {
    final target = _key(word);
    if (target.isEmpty) return false;
    return WordCheck.lookupKeysFor(guess).contains(target) ||
        _key(guess) == target;
  }

  /// True when [guess] is one letter away from [word] (one letter wrong,
  /// missing or extra), for words of 4 letters or more. Shorter words are
  /// too easy to hit by chance.
  static bool isClose(String guess, String word) {
    final a = _key(guess);
    final b = _key(word);
    if (b.replaceAll(' ', '').length < 4 || a == b) return false;
    return _oneEditApart(a, b);
  }

  static bool _oneEditApart(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (a.length < b.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    edits += (a.length - i) + (b.length - j);
    return edits == 1;
  }

  /// How many letters are given away as hints: two for words of 4 letters
  /// or more, one for 3 letters, none for shorter.
  static int hintCount(String word) {
    final letters = word.replaceAll(' ', '').length;
    if (letters >= 4) return 2;
    if (letters == 3) return 1;
    return 0;
  }

  /// When each hint is given, as a share of the drawing time gone: half
  /// way, then with a quarter left.
  static const hintTimes = [0.5, 0.75];

  /// [word] with every letter not in [revealed] (by position) as "_".
  /// Spaces stay, so players can see how many words there are.
  static String mask(String word, Set<int> revealed) {
    final buffer = StringBuffer();
    for (var index = 0; index < word.length; index++) {
      final character = word[index];
      buffer.write(
        character == ' ' || revealed.contains(index) ? character : '_',
      );
    }
    return buffer.toString();
  }

  /// Positions in [word] that hold letters.
  static List<int> letterPositions(String word) => [
    for (var index = 0; index < word.length; index++)
      if (word[index] != ' ') index,
  ];

  /// Players from most points to fewest, with ties sharing a rank and the
  /// next rank skipped, so 1, 2, 2, 4.
  static List<({String playerId, int rank, int points})> rank(
    Map<String, int> points,
    List<String> playerIds,
  ) {
    final sorted = [...playerIds]
      ..sort((a, b) => (points[b] ?? 0).compareTo(points[a] ?? 0));
    final ranked = <({String playerId, int rank, int points})>[];
    for (final (index, id) in sorted.indexed) {
      final score = points[id] ?? 0;
      final rank = index > 0 && ranked.last.points == score
          ? ranked.last.rank
          : index + 1;
      ranked.add((playerId: id, rank: rank, points: score));
    }
    return ranked;
  }

  /// Cleans a typed guess: trimmed, single spaces, and no longer than
  /// [maxGuessLength].
  static String cleanGuess(String text) {
    final single = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return single.length > maxGuessLength
        ? single.substring(0, maxGuessLength)
        : single;
  }
}
