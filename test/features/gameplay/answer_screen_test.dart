import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/widgets/countdown_ring.dart';
import 'package:thinkcraft_word_battle/core/widgets/game_text_field.dart';
import 'package:thinkcraft_word_battle/core/widgets/letter_badge.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

import '../../fakes.dart';
import '../../helpers.dart';

Finder _field(Category category) {
  return find.descendant(
    of: find.byKey(ValueKey('answer-${category.name}')),
    matching: find.byType(TextFormField),
  );
}

Future<FakeGameService> _open(
  WidgetTester tester, {
  Set<String> submitted = const {},
  Size size = const Size(360, 800),
}) async {
  final service = FakeGameService(
    fakeAnsweringRoom(
      deadline: clock.now().add(GameRules.answerTime),
      submitted: submitted,
    ),
  );
  await pumpGame(tester, service: service, size: size);
  await pumpFrames(tester);
  return service;
}

/// Taps the Lock In button without waiting to settle, because the running
/// countdown never settles.
Future<void> _tapLockIn(WidgetTester tester) async {
  // Let the scroll to the focused field finish first.
  await pumpFrames(tester);

  final button = find.text('Lock In Answers');
  await tester.ensureVisible(button);
  await pumpFrames(tester);
  await tester.tap(button);
  await pumpFrames(tester);
}

void main() {
  testWidgets('shows the letter, the timer and all six categories', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(LetterBadge), findsOneWidget);
    expect(find.text('Find M words!'), findsOneWidget);
    expect(find.byType(CountdownRing), findsOneWidget);
    expect(find.byType(GameTextField), findsNWidgets(6));
    for (final category in Category.values) {
      expect(find.text(category.label), findsOneWidget);
    }
  });

  testWidgets('the ring counts down from the deadline', (tester) async {
    await _open(tester);
    expect(find.text('90'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('the ring stops at zero', (tester) async {
    await _open(tester);

    await tester.pump(const Duration(seconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('typing is saved as you go', (tester) async {
    final service = await _open(tester);

    await tester.enterText(_field(Category.animal), 'Monkey');

    expect(service.typed[Category.animal], 'Monkey');
  });

  testWidgets('warns about a wrong starting letter', (tester) async {
    await _open(tester);

    await tester.enterText(_field(Category.animal), 'Banana');
    await tester.pump();
    expect(find.text("This doesn't start with M."), findsOneWidget);

    await tester.enterText(_field(Category.animal), 'Monkey');
    await tester.pump();
    expect(find.text("This doesn't start with M."), findsNothing);
  });

  testWidgets('a full form locks in straight away', (tester) async {
    final service = await _open(tester);

    for (final category in Category.values) {
      await tester.enterText(_field(category), 'Mango');
    }
    await _tapLockIn(tester);

    expect(service.calls, contains('submitAnswers'));
    expect(find.textContaining('blank'), findsNothing);
  });

  testWidgets('blank answers ask first, and you can keep going', (
    tester,
  ) async {
    final service = await _open(tester);

    await tester.enterText(_field(Category.animal), 'Monkey');
    await _tapLockIn(tester);
    expect(find.text('5 answers are blank'), findsOneWidget);

    await tester.tap(find.text('Keep Going'));
    await pumpFrames(tester);

    expect(service.calls, isNot(contains('submitAnswers')));
  });

  testWidgets('blank answers can still be locked in', (tester) async {
    final service = await _open(tester);

    await _tapLockIn(tester);
    await tester.tap(find.text('Lock In'));
    await pumpFrames(tester);

    expect(service.calls, contains('submitAnswers'));
  });

  testWidgets('locked answers cannot be edited', (tester) async {
    await _open(tester, submitted: {localId});

    for (final category in Category.values) {
      expect(tester.widget<TextFormField>(_field(category)).enabled, isFalse);
    }
    expect(find.text('Lock In Answers'), findsNothing);
    expect(find.textContaining('Waiting for'), findsOneWidget);
  });

  testWidgets('the locked message stays visible at any scroll position', (
    tester,
  ) async {
    await _open(tester, submitted: {localId});

    final message = find.textContaining('Answers locked!');
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: message,
      ),
      findsNothing,
    );
    expect(tester.getTopLeft(message).dy, lessThan(200));
  });

  testWidgets('counts how many players are left', (tester) async {
    await _open(tester, submitted: {localId, 'bot'});

    expect(
      find.text('Answers locked! Waiting for 1 more player...'),
      findsOneWidget,
    );
  });

  testWidgets('checks the deadline when the app returns', (tester) async {
    final service = await _open(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(service.calls, contains('refresh'));
  });

  testWidgets('moves on when the game does', (tester) async {
    final service = await _open(tester);

    service.emit(service.room!.copyWith(phase: GamePhase.validating));
    await pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(currentRoute(tester), AppRoutes.validation);
    expect(find.text('Answers are in!'), findsOneWidget);
  });

  testWidgets('the back button asks before leaving', (tester) async {
    await _open(tester);

    await tester.binding.handlePopRoute();
    await pumpFrames(tester);

    expect(find.text('Leave the game?'), findsOneWidget);
  });

  testWidgets('fits on a small phone', (tester) async {
    await _open(tester, size: const Size(320, 568));

    await tester.enterText(_field(Category.person), 'Xavier Long Answer Here');
    await pumpFrames(tester);

    expect(find.byType(GameTextField), findsNWidgets(6));
  });
}
