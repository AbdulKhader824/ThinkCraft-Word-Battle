import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/most_likely_room.dart';
import 'package:thinkcraft_word_battle/models/player.dart';
import 'package:thinkcraft_word_battle/services/most_likely_questions.dart';
import 'package:thinkcraft_word_battle/services/rules/most_likely_rules.dart';
import 'package:thinkcraft_word_battle/services/rules/rude_words.dart';

void main() {
  group('most likely', () {
    test('the player with the most votes', () {
      expect(
        MostLikelyRules.mostLikely({
          'riya': 'sam',
          'ali': 'sam',
          'sam': 'riya',
          'zara': 'sam',
        }),
        {'sam'},
      );
    });

    test('players can vote for themselves', () {
      final votes = {'riya': 'riya', 'ali': 'riya', 'sam': 'ali'};
      expect(MostLikelyRules.tally(votes), {'riya': 2, 'ali': 1});
      expect(MostLikelyRules.mostLikely(votes), {'riya'});
    });

    test('a tie makes everyone tied most likely', () {
      expect(
        MostLikelyRules.mostLikely({
          'riya': 'sam',
          'ali': 'zara',
          'sam': 'zara',
          'zara': 'sam',
        }),
        {'sam', 'zara'},
      );
    });

    test('no votes means nobody', () {
      expect(MostLikelyRules.mostLikely({}), isEmpty);
    });
  });

  group('mind-reader points', () {
    test('a point for voting with the most votes, none otherwise', () {
      expect(
        MostLikelyRules.points({
          'riya': 'sam',
          'ali': 'sam',
          'sam': 'riya',
          'zara': 'sam',
        }),
        {'riya': 1, 'ali': 1, 'sam': 0, 'zara': 1},
      );
    });

    test('on a tie, voting for any of the tied players scores', () {
      expect(
        MostLikelyRules.points({
          'riya': 'sam',
          'ali': 'zara',
          'sam': 'zara',
          'zara': 'sam',
          'meera': 'riya',
        }),
        {'riya': 1, 'ali': 1, 'sam': 1, 'zara': 1, 'meera': 0},
      );
    });

    test('players who did not vote get nothing', () {
      final points = MostLikelyRules.points({'riya': 'sam', 'ali': 'sam'});
      expect(points, {'riya': 1, 'ali': 1});
      expect(MostLikelyRules.points({}), isEmpty);
    });

    test('points add up into scores', () {
      expect(
        MostLikelyRules.addPoints({'riya': 3, 'ali': 1}, {'ali': 2, 'sam': 1}),
        {'riya': 3, 'ali': 3, 'sam': 1},
      );
    });
  });

  test('titles collect the questions each player won, ties too', () {
    var titles = MostLikelyRules.addTitle({}, {'sam'}, 'become famous');
    titles = MostLikelyRules.addTitle(titles, {'sam', 'riya'}, 'live on Mars');
    titles = MostLikelyRules.addTitle(titles, {}, 'ride a camel');
    expect(titles, {
      'sam': ['become famous', 'live on Mars'],
      'riya': ['live on Mars'],
    });
  });

  test('the most points win, and ties share the win', () {
    expect(MostLikelyRules.winners({'riya': 4, 'ali': 6, 'sam': 2}), ['ali']);
    expect(
      MostLikelyRules.winners({'riya': 6, 'ali': 6, 'sam': 2}),
      unorderedEquals(['riya', 'ali']),
    );
    expect(MostLikelyRules.winners({'riya': 0, 'ali': 0}), isEmpty);
  });

  group('questions', () {
    final all = [
      for (final topic in MostLikelyTopic.values)
        ...MostLikelyQuestions.forTopic(topic),
    ];

    test('about 200 questions, unique, lower case to start and kind', () {
      expect(all.length, greaterThanOrEqualTo(200));
      expect(all.toSet(), hasLength(all.length));
      for (final topic in MostLikelyTopic.values) {
        expect(MostLikelyQuestions.forTopic(topic).length, greaterThan(40));
      }
      for (final question in all) {
        expect(soundsRude(question), isFalse, reason: question);
        expect(question.trim(), question, reason: question);
        expect(question, isNot(endsWith('?')), reason: question);
        // Each finishes "Who is most likely to ...", so it starts with a
        // small letter, unless it's a name like Mars.
        expect(question[0], question[0].toLowerCase(), reason: question);
      }
    });

    test('questions never repeat until a topic runs out', () {
      final random = Random(4);
      final used = <String>{};
      final topics = {MostLikelyTopic.silly};
      final count = MostLikelyQuestions.forTopic(MostLikelyTopic.silly).length;
      for (var i = 0; i < count; i++) {
        final pick = MostLikelyQuestions.pick(topics, random, used: used);
        expect(used.add(pick.question), isTrue);
      }
      // All used: it starts again rather than failing.
      final again = MostLikelyQuestions.pick(topics, random, used: used);
      expect(used, contains(again.question));
    });

    test('only the chosen topics are used', () {
      final random = Random(9);
      final topics = {MostLikelyTopic.future, MostLikelyTopic.everyday};
      for (var i = 0; i < 40; i++) {
        final pick = MostLikelyQuestions.pick(topics, random);
        expect(topics, contains(pick.topic));
        expect(
          MostLikelyQuestions.forTopic(pick.topic),
          contains(pick.question),
        );
      }
    });
  });

  group('settings', () {
    test('check their choices', () {
      expect(MostLikelySettings().questions, 10);
      expect(MostLikelySettings().topics, MostLikelyTopic.values.toSet());
      expect(MostLikelySettings(questions: 20).rounds, 4);
      expect(() => MostLikelySettings(questions: 7), throwsArgumentError);
      expect(() => MostLikelySettings(topics: {}), throwsArgumentError);
    });
  });

  group('room', () {
    MostLikelyRoom room({int questionNumber = 0, int questions = 10}) =>
        MostLikelyRoom(
          code: 'ABC234',
          players: const [
            Player(id: 'sam', name: 'Sam', avatarIndex: 0, isHost: true),
            Player(id: 'riya', name: 'Riya', avatarIndex: 1),
          ],
          settings: MostLikelySettings(questions: questions),
          questionNumber: questionNumber,
          question: 'become famous',
        );

    test('reads the question in full', () {
      expect(room().questionText, 'Who is most likely to become famous?');
    });

    test('five questions make a round', () {
      expect(room().round, 0);
      expect(room(questionNumber: 1).round, 1);
      expect(room(questionNumber: 5).round, 1);
      expect(room(questionNumber: 5).isLastOfRound, isTrue);
      expect(room(questionNumber: 6).round, 2);
      expect(room(questionNumber: 6).isLastOfRound, isFalse);
      expect(room(questionNumber: 10).isFinalRound, isTrue);
      expect(room(questionNumber: 10, questions: 15).isFinalRound, isFalse);
    });

    test('needs 3 ready players to start', () {
      expect(room().canStart, isFalse);
    });
  });
}
