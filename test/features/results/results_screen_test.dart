import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/theme/app_colors.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';

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
  Size size = const Size(360, 800),
}) async {
  final service = FakeGameService(
    fakeResultsRoom(
      roundNumber: roundNumber,
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
    expect(find.text('Validation: +2'), findsOneWidget);
    expect(find.text('Round: 15.33'), findsOneWidget);
  });

  testWidgets('shows negative validation points', (tester) async {
    await _open(tester);

    await tapAndSettle(tester, find.text('Luna'));

    expect(find.text('Validation: -1'), findsOneWidget);
  });

  testWidgets('shows answers with their validity', (tester) async {
    await _open(tester);

    await tapAndSettle(tester, find.text('Sam (you)'));

    expect(find.text('Monkey'), findsOneWidget);
    expect(find.text('Valid'), findsNWidgets(2));
    expect(find.text('Invalid'), findsOneWidget);
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

  testWidgets('later rounds show who is leading', (tester) async {
    await _open(tester, roundNumber: 2);

    expect(find.text('Sam is leading!'), findsOneWidget);
    expect(find.text('Round 2 results'), findsOneWidget);
  });

  testWidgets('Play Again asks for the next round', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Play Again'));

    expect(service.calls, contains('playAgain'));
  });

  testWidgets('Return Home leaves the game', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Return Home'));

    expect(service.calls, contains('leaveRoom'));
    expect(currentRoute(tester), AppRoutes.home);
  });

  testWidgets('fits on a small phone', (tester) async {
    await _open(tester, size: const Size(320, 568));

    expect(find.text('Play Again'), findsOneWidget);
    expect(find.text('Return Home'), findsOneWidget);
  });
}
