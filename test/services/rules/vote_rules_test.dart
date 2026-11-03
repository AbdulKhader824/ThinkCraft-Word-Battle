import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/rules/vote_rules.dart';

AnswerGroup _group({
  Set<String> authors = const {'author'},
  AnswerVerdict? autoVerdict,
}) {
  return AnswerGroup(
    id: 'food:mango',
    category: Category.food,
    text: 'Mango',
    authorIds: authors,
    autoVerdict: autoVerdict,
  );
}

Vote _vote(String voter, bool isValid) {
  return Vote(voterId: voter, groupId: 'food:mango', isValid: isValid);
}

List<Vote> _votes({int valid = 0, int invalid = 0}) {
  return [
    for (var index = 0; index < valid; index++) _vote('yes$index', true),
    for (var index = 0; index < invalid; index++) _vote('no$index', false),
  ];
}

void main() {
  group('canVote', () {
    test('other players can vote', () {
      expect(VoteRules.canVote(_group(), 'other'), isTrue);
    });

    test('a player cannot vote on their own answer', () {
      expect(VoteRules.canVote(_group(), 'author'), isFalse);
    });

    test('anyone who shares the answer cannot vote on it', () {
      final group = _group(authors: {'a', 'b'});

      expect(VoteRules.canVote(group, 'a'), isFalse);
      expect(VoteRules.canVote(group, 'b'), isFalse);
      expect(VoteRules.canVote(group, 'c'), isTrue);
    });

    test('nobody votes on an answer already decided', () {
      final group = _group(autoVerdict: AnswerVerdict.invalid);

      expect(VoteRules.canVote(group, 'other'), isFalse);
    });
  });

  group('addVote', () {
    test('adds a new vote without changing the original list', () {
      final original = <Vote>[];

      final updated = VoteRules.addVote(original, _vote('a', true), _group());

      expect(updated, hasLength(1));
      expect(original, isEmpty);
    });

    test('rejects voting on your own answer', () {
      expect(
        () => VoteRules.addVote([], _vote('author', true), _group()),
        throwsStateError,
      );
    });

    test('rejects a duplicate vote', () {
      final votes = VoteRules.addVote([], _vote('a', true), _group());

      expect(
        () => VoteRules.addVote(votes, _vote('a', false), _group()),
        throwsStateError,
      );
    });

    test('one voter can vote on different answers', () {
      final votes = VoteRules.addVote([], _vote('a', true), _group());
      final other = AnswerGroup(
        id: 'food:melon',
        category: Category.food,
        text: 'Melon',
        authorIds: const {'author'},
      );

      final updated = VoteRules.addVote(
        votes,
        const Vote(voterId: 'a', groupId: 'food:melon', isValid: false),
        other,
      );

      expect(updated, hasLength(2));
    });
  });

  group('verdictFor', () {
    test('more valid votes means valid', () {
      expect(
        VoteRules.verdictFor(_group(), _votes(valid: 2, invalid: 1)),
        AnswerVerdict.valid,
      );
    });

    test('more invalid votes means invalid', () {
      expect(
        VoteRules.verdictFor(_group(), _votes(valid: 1, invalid: 2)),
        AnswerVerdict.invalid,
      );
    });

    test('a tie is disputed', () {
      expect(
        VoteRules.verdictFor(_group(), _votes(valid: 2, invalid: 2)),
        AnswerVerdict.disputed,
      );
    });

    test('no votes at all is disputed', () {
      expect(VoteRules.verdictFor(_group(), []), AnswerVerdict.disputed);
    });

    test('in a 2-player game the only voter decides', () {
      expect(
        VoteRules.verdictFor(_group(), _votes(valid: 1)),
        AnswerVerdict.valid,
      );
      expect(
        VoteRules.verdictFor(_group(), _votes(invalid: 1)),
        AnswerVerdict.invalid,
      );
    });

    test('an automatic verdict always wins', () {
      final group = _group(autoVerdict: AnswerVerdict.valid);

      expect(
        VoteRules.verdictFor(group, _votes(invalid: 3)),
        AnswerVerdict.valid,
      );
    });

    test('only counts votes for this answer', () {
      final votes = [
        ..._votes(valid: 1),
        const Vote(voterId: 'x', groupId: 'other', isValid: false),
        const Vote(voterId: 'y', groupId: 'other', isValid: false),
      ];

      expect(VoteRules.verdictFor(_group(), votes), AnswerVerdict.valid);
    });
  });
}
