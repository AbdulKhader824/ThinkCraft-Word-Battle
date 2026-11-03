import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/services/rules/answer_rules.dart';

Answer _answer(String playerId, String text, [Category? category]) {
  return Answer(
    playerId: playerId,
    category: category ?? Category.food,
    text: text,
  );
}

List<AnswerGroup> _group(
  List<Answer> answers, {
  List<String> players = const ['a', 'b', 'c'],
}) {
  return AnswerRules.groupAnswers(
    answers: answers,
    letter: 'M',
    playerIds: players,
  );
}

void main() {
  group('normalize', () {
    test('ignores capitals', () {
      expect(AnswerRules.normalize('MANGO'), AnswerRules.normalize('mango'));
    });

    test('ignores spaces at the ends and repeated spaces', () {
      expect(
        AnswerRules.normalize('  Ice    Cream '),
        AnswerRules.normalize('ice cream'),
      );
    });

    test('keeps different spellings apart', () {
      expect(
        AnswerRules.normalize('Mango'),
        isNot(AnswerRules.normalize('Mangoes')),
      );
    });
  });

  group('groupAnswers', () {
    test('groups identical answers, ignoring capitals and spaces', () {
      final groups = _group(
        [_answer('a', 'Mango'), _answer('b', ' mango '), _answer('c', 'MANGO')],
        players: ['a', 'b', 'c', 'd'],
      );

      expect(groups, hasLength(1));
      expect(groups.single.authorIds, {'a', 'b', 'c'});
    });

    test('keeps different answers in separate groups', () {
      final groups = _group([_answer('a', 'Mango'), _answer('b', 'Melon')]);

      expect(groups, hasLength(2));
    });

    test('keeps the same word in different categories apart', () {
      final groups = _group([
        _answer('a', 'Mango', Category.food),
        _answer('b', 'Mango', Category.brand),
      ]);

      expect(groups, hasLength(2));
      expect(groups.map((g) => g.id).toSet(), hasLength(2));
    });

    test('tidies the text shown to voters', () {
      final groups = _group([_answer('a', '  Ice    Cream ')]);

      expect(groups.single.text, 'Ice Cream');
    });

    test('leaves out empty answers', () {
      final groups = _group([_answer('a', ''), _answer('b', '   ')]);

      expect(groups, isEmpty);
    });

    test('a normal answer needs a vote', () {
      final group = _group([_answer('a', 'Mango')]).single;

      expect(group.needsVote, isTrue);
      expect(group.autoVerdict, isNull);
    });
  });

  group('answers decided without a vote', () {
    test('a wrong starting letter is invalid straight away', () {
      final group = _group([_answer('a', 'Banana')]).single;

      expect(group.needsVote, isFalse);
      expect(group.autoVerdict, AnswerVerdict.invalid);
    });

    test('when everyone gave the same answer, it is valid', () {
      final group = _group(
        [_answer('a', 'Mango'), _answer('b', 'mango')],
        players: ['a', 'b'],
      ).single;

      expect(group.needsVote, isFalse);
      expect(group.autoVerdict, AnswerVerdict.valid);
    });

    test('a shared answer with someone left to vote still needs a vote', () {
      final group = _group([_answer('a', 'Mango'), _answer('b', 'Mango')])
          .single;

      expect(group.needsVote, isTrue);
    });

    test('everyone sharing a wrong-letter answer is still invalid', () {
      final group = _group(
        [_answer('a', 'Banana'), _answer('b', 'Banana')],
        players: ['a', 'b'],
      ).single;

      expect(group.autoVerdict, AnswerVerdict.invalid);
    });
  });
}
