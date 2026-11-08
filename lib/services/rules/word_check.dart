import '../../models/answer_group.dart';
import '../../models/category.dart';
import '../../models/game_settings.dart';

/// Answers known to be real, by category.
abstract interface class WordList {
  /// True when [answer] is a known [category], allowing for capitals,
  /// accents, plurals, "the" and British or American spelling.
  bool contains(Category category, String answer);
}

/// A [WordList] held in memory.
class SetWordList implements WordList {
  /// [words] may be in any form: each is turned into a match key here.
  SetWordList(Map<Category, Iterable<String>> words)
    : _words = {
        for (final MapEntry(key: category, value: list) in words.entries)
          category: {
            for (final word in list)
              if (WordCheck.keyFor(word).isNotEmpty) WordCheck.keyFor(word),
          },
      };

  final Map<Category, Set<String>> _words;

  /// How many answers [category] knows.
  int sizeOf(Category category) => _words[category]?.length ?? 0;

  @override
  bool contains(Category category, String answer) {
    final words = _words[category];
    if (words == null) return false;
    return WordCheck.lookupKeysFor(answer).any(words.contains);
  }
}

/// Checks answers against a [WordList]. Plain Dart, with no Flutter
/// imports.
abstract final class WordCheck {
  static final _apostrophes = RegExp("['’]");
  static final _notLetters = RegExp('[^a-z0-9]+');

  /// "our" after at least two letters, with a common ending: colour,
  /// flavoured, favourite. "four" and "hour" are left alone.
  static final _britishOur = RegExp(
    r'^([a-z]{2,})our(s|ed|ing|ite|ites|ful|able|less)?$',
  );
  static final _britishTre = RegExp(r'^([a-z]{2,})tre$');

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ç': 'c',
    'č': 'c',
    'ć': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ñ': 'n',
    'ń': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'š': 's',
    'ś': 's',
    'ž': 'z',
    'ź': 'z',
    'ż': 'z',
    'ł': 'l',
    'ß': 'ss',
    'æ': 'ae',
    'œ': 'oe',
  };

  /// The form two answers are compared in: lower case, no accents or
  /// punctuation, no "the" at the start, and one spelling for words that
  /// British and American English spell differently.
  static String keyFor(String text) {
    final lower = text.toLowerCase();
    final plain = StringBuffer();
    for (final rune in lower.runes) {
      final letter = String.fromCharCode(rune);
      plain.write(_accents[letter] ?? letter);
    }
    var words = plain
        .toString()
        .replaceAll('&', ' and ')
        .replaceAll(_apostrophes, '')
        .replaceAll(_notLetters, ' ')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length > 1 && words.first == 'the') words = words.sublist(1);
    return words.map(_oneSpelling).join(' ');
  }

  /// Colour and color, flavoured and flavored, centre and center: one
  /// spelling for both.
  static String _oneSpelling(String word) {
    return word
        .replaceFirstMapped(
          _britishOur,
          (match) => '${match[1]}or${match[2] ?? ''}',
        )
        .replaceFirstMapped(_britishTre, (match) => '${match[1]}ter');
  }

  /// The keys to look an answer up by: itself, and the singular of its last
  /// word, so "Bears" finds Bear and "Cherries" finds Cherry.
  static List<String> lookupKeysFor(String answer) {
    final key = keyFor(answer);
    if (key.isEmpty) return const [];
    final keys = [key];
    if (key.length > 4 && key.endsWith('ies')) {
      keys.add('${key.substring(0, key.length - 3)}y');
    }
    if (key.length > 3 && key.endsWith('es')) {
      keys.add(key.substring(0, key.length - 2));
    }
    if (key.length > 3 && key.endsWith('s') && !key.endsWith('ss')) {
      keys.add(key.substring(0, key.length - 1));
    }
    return keys;
  }

  /// Settles the answers the word list can, depending on [mode]:
  ///
  /// * [AnswerCheck.vote]: none; everything is voted on.
  /// * [AnswerCheck.smart]: answers in the list are correct; the rest are
  ///   voted on.
  /// * [AnswerCheck.auto]: answers in the list are correct, and the rest
  ///   are wrong, so nothing is voted on.
  ///
  /// Answers already settled, such as one with the wrong first letter,
  /// keep their verdict. Without a word list, everything is voted on.
  static List<AnswerGroup> apply(
    List<AnswerGroup> groups,
    WordList? words,
    AnswerCheck mode,
  ) {
    if (words == null || mode == AnswerCheck.vote) return groups;

    return [
      for (final group in groups)
        if (!group.needsVote)
          group
        else if (words.contains(group.category, group.text))
          group.settledByWordList(AnswerVerdict.valid)
        else if (mode == AnswerCheck.auto)
          group.settledByWordList(AnswerVerdict.invalid)
        else
          group,
    ];
  }
}
