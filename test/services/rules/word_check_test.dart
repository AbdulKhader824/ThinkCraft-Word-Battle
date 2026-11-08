import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/services/rules/word_check.dart';

final _words = SetWordList({
  Category.animal: ['Bear', 'Cherry Shrimp', 'Mountain lion'],
  Category.place: ['Zürich', 'The Bahamas', 'New York'],
  Category.food: ['Cherry', 'Tomato'],
  Category.movie: ['The Lion King'],
  Category.brand: ['Marks & Spencer', "McDonald's"],
});

AnswerGroup _group(String text, {AnswerVerdict? auto}) => AnswerGroup(
  id: 'animal:${text.toLowerCase()}',
  category: Category.animal,
  text: text,
  authorIds: const {'a'},
  autoVerdict: auto,
);

void main() {
  group('matching', () {
    test('ignores capitals and spaces', () {
      expect(_words.contains(Category.animal, '  bEAR '), isTrue);
      expect(_words.contains(Category.animal, 'mountain   LION'), isTrue);
    });

    test('ignores accents', () {
      expect(_words.contains(Category.place, 'Zurich'), isTrue);
      expect(_words.contains(Category.place, 'ZÜRICH'), isTrue);
    });

    test('ignores "the" at the start', () {
      expect(_words.contains(Category.place, 'Bahamas'), isTrue);
      expect(_words.contains(Category.movie, 'lion king'), isTrue);
      expect(_words.contains(Category.movie, 'The Lion King'), isTrue);
    });

    test('finds plurals', () {
      expect(_words.contains(Category.animal, 'Bears'), isTrue);
      expect(_words.contains(Category.food, 'Cherries'), isTrue);
      expect(_words.contains(Category.food, 'Tomatoes'), isTrue);
    });

    test('ignores punctuation, and & is "and"', () {
      expect(_words.contains(Category.brand, 'Marks and Spencer'), isTrue);
      expect(_words.contains(Category.brand, 'mcdonalds'), isTrue);
      expect(_words.contains(Category.place, 'New-York'), isTrue);
    });

    test('British and American spellings match', () {
      final words = SetWordList({
        Category.food: ['Flavoured water'],
        Category.place: ['Rockefeller Center'],
      });
      expect(words.contains(Category.food, 'flavored water'), isTrue);
      expect(words.contains(Category.place, 'Rockefeller Centre'), isTrue);
    });

    test('a word only counts in its own category', () {
      expect(_words.contains(Category.food, 'Bear'), isFalse);
      expect(_words.contains(Category.person, 'Bear'), isFalse);
    });

    test('typos and blanks are not found', () {
      expect(_words.contains(Category.animal, 'Baer'), isFalse);
      expect(_words.contains(Category.animal, ''), isFalse);
      expect(_words.contains(Category.animal, '!!!'), isFalse);
    });
  });

  group('answer check', () {
    final known = _group('Bear');
    final unknown = _group('Blorp');
    final wrongLetter = _group('Cat', auto: AnswerVerdict.invalid);

    test('smart check settles known words and votes on the rest', () {
      final groups = WordCheck.apply(
        [known, unknown],
        _words,
        AnswerCheck.smart,
      );

      expect(groups[0].autoVerdict, AnswerVerdict.valid);
      expect(groups[0].checkedByWordList, isTrue);
      expect(groups[1].needsVote, isTrue);
    });

    test('auto only marks unknown words wrong', () {
      final groups = WordCheck.apply(
        [known, unknown],
        _words,
        AnswerCheck.auto,
      );

      expect(groups[0].autoVerdict, AnswerVerdict.valid);
      expect(groups[1].autoVerdict, AnswerVerdict.invalid);
      expect(groups[1].checkedByWordList, isTrue);
      expect(groups.any((group) => group.needsVote), isFalse);
    });

    test('players vote leaves every answer to the vote', () {
      final groups = WordCheck.apply([known], _words, AnswerCheck.vote);
      expect(groups.single.needsVote, isTrue);
    });

    test('without a word list, everything is voted on', () {
      final groups = WordCheck.apply([known], null, AnswerCheck.auto);
      expect(groups.single.needsVote, isTrue);
    });

    test('an answer already settled keeps its verdict', () {
      final groups = WordCheck.apply([wrongLetter], _words, AnswerCheck.auto);
      expect(groups.single.autoVerdict, AnswerVerdict.invalid);
      expect(groups.single.checkedByWordList, isFalse);
    });
  });

  group('full names in Person Name', () {
    final names = SetWordList({
      Category.person: ['Priya', 'Sharma', 'Arjun', 'Kumar', 'Virat Kohli'],
      Category.animal: ['Panda', 'Tiger'],
    });

    test('a known full name counts', () {
      expect(names.contains(Category.person, 'Virat Kohli'), isTrue);
    });

    test('a first and family name together count', () {
      expect(names.contains(Category.person, 'Priya Sharma'), isTrue);
      expect(names.contains(Category.person, 'arjun kumar sharma'), isTrue);
    });

    test('an unknown part, or too many parts, does not', () {
      expect(names.contains(Category.person, 'Priya Blorp'), isFalse);
      expect(
        names.contains(Category.person, 'Priya Arjun Kumar Sharma'),
        isFalse,
      );
    });

    test('only Person Name joins parts like this', () {
      expect(names.contains(Category.animal, 'Panda Tiger'), isFalse);
    });
  });

  test('lists the words starting with a letter, in either case', () {
    final words = SetWordList({
      Category.animal: ['Panda', 'Parrot', 'Tiger'],
    });
    expect(
      words.wordsStartingWith(Category.animal, 'p'),
      unorderedEquals(['panda', 'parrot']),
    );
    expect(words.wordsStartingWith(Category.animal, 'T'), ['tiger']);
    expect(words.wordsStartingWith(Category.animal, 'Z'), isEmpty);
    expect(words.wordsStartingWith(Category.food, 'P'), isEmpty);
  });
}
