import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/theme/app_colors.dart';
import 'package:thinkcraft_word_battle/core/widgets/countdown_ring.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

import '../../fakes.dart';
import '../../helpers.dart';

const _lines = [
  AnswerLine(
    category: Category.animal,
    text: 'Monkey',
    verdict: AnswerVerdict.valid,
    points: 1000,
  ),
  AnswerLine(
    category: Category.place,
    text: 'Mango',
    verdict: AnswerVerdict.invalid,
    points: 0,
  ),
  AnswerLine(
    category: Category.person,
    text: 'Maya',
    verdict: AnswerVerdict.disputed,
    points: 0,
  ),
  AnswerLine(category: Category.movie, text: '', verdict: null, points: 0),
  AnswerLine(
    category: Category.food,
    text: 'Melon',
    verdict: AnswerVerdict.valid,
    points: 333,
  ),
];

Future<FakeGameService> _open(
  WidgetTester tester, {
  Map<String, ScoreLine>? scores,
  int roundNumber = 1,
  int rounds = 1,
  Size size = const Size(360, 800),
  Set<String> nextRoundReady = const {},
}) async {
  final service = FakeGameService(
    fakeResultsRoom(
      roundNumber: roundNumber,
      rounds: rounds,
      nextRoundReady: nextRoundReady,
      lines: {localId: _lines},
      scores:
          scores ??
          const {
            localId: ScoreLine(answerPoints: 1333, validationPoints: 2),
            'bot': ScoreLine(answerPoints: 1000, validationPoints: -1),
            'bot2': ScoreLine(answerPoints: 500),
          },
    ),
  );
  await pumpGame(tester, service: service, size: size);
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('announces the winner and lists every player', (tester) async {
    await _open(tester);

    expect(find.text('Sam wins!'), findsOneWidget);
    expect(find.text('Sam (you)'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
  });

  testWidgets('orders the leaderboard by total', (tester) async {
    await _open(tester);

    final sam = tester.getTopLeft(find.text('Sam (you)')).dy;
    final luna = tester.getTopLeft(find.text('Luna')).dy;
    final kai = tester.getTopLeft(find.text('Kai')).dy;

    expect(sam, lessThan(luna));
    expect(luna, lessThan(kai));
  });

  testWidgets('tied players share a rank', (tester) async {
    await _open(
      tester,
      scores: const {
        localId: ScoreLine(answerPoints: 1000),
        'bot': ScoreLine(answerPoints: 1000),
        'bot2': ScoreLine(answerPoints: 500),
      },
    );

    expect(find.text("It's a tie!"), findsOneWidget);
    expect(find.text('#1'), findsNWidgets(2));
    expect(find.text('#2'), findsNothing);
    expect(find.text('#3'), findsOneWidget);
  });

  testWidgets('the leaderboard starts collapsed, so all of it shows', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('Monkey'), findsNothing);
    expect(find.text('Tap a player to see their answers.'), findsOneWidget);
  });

  testWidgets('shows answer and validation points separately', (tester) async {
    await _open(tester);

    await tapAndSettle(tester, find.text('Sam (you)'));

    expect(find.text('Answers: 13.33'), findsOneWidget);
    expect(find.text('Votes: +2'), findsOneWidget);
    expect(find.text('Round: 15.33'), findsOneWidget);
  });

  testWidgets('shows negative validation points', (tester) async {
    await _open(tester);

    await tapAndSettle(tester, find.text('Luna'));

    expect(find.text('Votes: -1'), findsOneWidget);
  });

  testWidgets('shows answers with their validity', (tester) async {
    await _open(tester);

    await tapAndSettle(tester, find.text('Sam (you)'));

    expect(find.text('Monkey'), findsOneWidget);
    expect(find.text('Correct'), findsNWidgets(2));
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('Tied'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('No answer'), findsOneWidget);
    expect(find.text('3.33'), findsOneWidget);
  });

  testWidgets('gives a star for each unique answer', (tester) async {
    await _open(tester);

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('gives the top three trophies', (tester) async {
    await _open(tester);

    final colors = tester
        .widgetList<Icon>(find.byIcon(Icons.emoji_events_rounded))
        .map((icon) => icon.color);

    expect(colors, contains(AppColors.gold));
    expect(colors, contains(AppColors.silver));
    expect(colors, contains(AppColors.bronze));
  });

  testWidgets('before the last round, shows who is leading', (tester) async {
    await _open(tester, roundNumber: 2, rounds: 5);

    expect(find.text('Sam is leading!'), findsOneWidget);
    expect(find.text('Round 2 of 5 results'), findsOneWidget);
  });

  testWidgets('before the last round, offers the next round', (tester) async {
    final service = await _open(tester, roundNumber: 2, rounds: 5);

    expect(find.text('New Game'), findsNothing);
    await tapAndSettle(tester, find.text('Next Round'));

    expect(service.calls, contains('nextRound'));
  });

  testWidgets('after the last round, announces the final winner', (
    tester,
  ) async {
    await _open(tester, roundNumber: 5, rounds: 5);

    expect(find.text('Sam wins!'), findsOneWidget);
    expect(find.text('Final results after 5 rounds'), findsOneWidget);
  });

  testWidgets('after the last round, offers a new game', (tester) async {
    final service = await _open(tester, roundNumber: 5, rounds: 5);

    expect(find.text('Next Round'), findsNothing);
    await tapAndSettle(tester, find.text('New Game'));

    expect(service.calls, contains('newGame'));
  });

  testWidgets('before the last round, there is no way home', (tester) async {
    await _open(tester, roundNumber: 2, rounds: 5);

    expect(find.text('Return Home'), findsNothing);
  });

  testWidgets('shows who is ready for the next round', (tester) async {
    await _open(tester, roundNumber: 1, rounds: 3, nextRoundReady: {'bot'});

    expect(find.bySemanticsLabel('Luna, ready'), findsOneWidget);
    expect(find.bySemanticsLabel('Kai, waiting'), findsOneWidget);
    expect(find.bySemanticsLabel('You, waiting'), findsOneWidget);
    expect(find.text('Press Next Round when you are ready!'), findsOneWidget);
  });

  testWidgets('once ready, waits for the others', (tester) async {
    await _open(tester, roundNumber: 1, rounds: 3, nextRoundReady: {localId});

    expect(find.text('Waiting for 2 more players...'), findsOneWidget);
    final button = tester.widget<InkWell>(buttonLabelled('Waiting...'));
    expect(button.onTap, isNull, reason: 'Next Round is pressed only once');
  });

  testWidgets('counts down the wait for the next round', (tester) async {
    final service = FakeGameService(
      fakeResultsRoom(
        scores: const {},
        rounds: 3,
        nextRoundDeadline: clock.now().add(GameRules.nextRoundWait),
      ),
    );
    await pumpGame(tester, service: service);
    await pumpFrames(tester);

    expect(find.byType(CountdownRing), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('Return Home leaves the game', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Return Home'));

    expect(service.calls, contains('leaveRoom'));
    expect(currentRoute(tester), AppRoutes.home);
  });

  testWidgets('fits on a small phone', (tester) async {
    await _open(tester, size: const Size(320, 568));

    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('Return Home'), findsOneWidget);
  });
}
