import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/widgets/confetti_burst.dart';
import 'package:thinkcraft_word_battle/features/results/results_screen.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';

import '../../fakes.dart';
import '../../helpers.dart';

const _iWin = {
  localId: ScoreLine(answerPoints: 2000),
  'bot': ScoreLine(answerPoints: 1000),
  'bot2': ScoreLine(answerPoints: 500),
};

const _iLose = {
  localId: ScoreLine(answerPoints: 500),
  'bot': ScoreLine(answerPoints: 2000),
  'bot2': ScoreLine(answerPoints: 1000),
};

Future<void> _open(
  WidgetTester tester,
  Map<String, ScoreLine> scores, {
  bool reduceMotion = true,
}) async {
  await pumpGame(
    tester,
    service: FakeGameService(fakeResultsRoom(scores: scores)),
    reduceMotion: reduceMotion,
  );
  await tester.pump();
}

/// Runs the screen's animations to the end. pumpAndSettle can't be used,
/// because Tilo floats forever when motion is allowed.
Future<void> _playAnimations(WidgetTester tester) async {
  for (var step = 0; step < 40; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('confetti celebrates first place', (tester) async {
    await _open(tester, _iWin, reduceMotion: false);

    expect(find.byType(ConfettiBurst), findsOneWidget);
    await _playAnimations(tester);
  });

  testWidgets('no confetti when someone else wins', (tester) async {
    await _open(tester, _iLose, reduceMotion: false);

    expect(find.byType(ConfettiBurst), findsNothing);
    await _playAnimations(tester);
  });

  testWidgets('confetti draws nothing when motion is reduced', (tester) async {
    await _open(tester, _iWin);

    final confetti = find.descendant(
      of: find.byType(ConfettiBurst),
      matching: find.byType(CustomPaint),
    );
    expect(confetti, findsNothing);
  });

  testWidgets('totals count up to their final value', (tester) async {
    await _open(tester, _iWin, reduceMotion: false);

    await tester.pump(ResultsScreen.entrance * 0.4);
    expect(find.text('20'), findsNothing);

    await _playAnimations(tester);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('everything shows at once when motion is reduced', (
    tester,
  ) async {
    await _open(tester, _iWin);

    expect(find.text('20'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('confetti never blocks the buttons', (tester) async {
    final service = FakeGameService(fakeResultsRoom(scores: _iWin));
    await pumpGame(tester, service: service, reduceMotion: false);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Play Again'));
    await tester.pump();

    expect(service.calls, contains('playAgain'));
    await _playAnimations(tester);
  });
}
