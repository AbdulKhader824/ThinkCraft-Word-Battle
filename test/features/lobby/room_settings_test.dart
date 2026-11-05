import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/widgets/game_text_field.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

import '../../fakes.dart';
import '../../helpers.dart';

Finder _rounds(int count) => find.byKey(ValueKey('round-count-$count'));

Finder _category(Category category) {
  return find.byKey(ValueKey('category-${category.name}'));
}

Future<FakeGameService> _openCreateRoom(WidgetTester tester) async {
  final service = FakeGameService(null);
  await pumpGame(tester, service: service);
  await goToWordBattle(tester);
  await tapAndSettle(tester, buttonLabelled('Create Room'));
  await tester.enterText(find.byType(TextFormField).first, 'Sam');
  return service;
}

Future<void> _create(WidgetTester tester) async {
  await tapAndSettle(tester, buttonLabelled('Create Room'));
}

void main() {
  group('Create Room settings', () {
    testWidgets('starts with 3 rounds and every category', (tester) async {
      final service = await _openCreateRoom(tester);

      await _create(tester);

      final settings = service.createdWith!;
      expect(settings.rounds, 3);
      expect(settings.usesEveryCategory, isTrue);
      expect(find.text('Categories (6 of 6)'), findsOneWidget);
    });

    testWidgets('starts the timer at 90 seconds', (tester) async {
      final service = await _openCreateRoom(tester);

      await _create(tester);

      expect(service.createdWith!.answerSeconds, 90);
    });

    testWidgets('offers 30, 60 and 90 second timers', (tester) async {
      await _openCreateRoom(tester);

      for (final seconds in GameSettings.answerSecondsOptions) {
        final tile = find.byKey(ValueKey('answer-time-$seconds'));
        expect(tile, findsOneWidget);
        expect(find.text('${seconds}s'), findsOneWidget);
        expect(
          tester.getSemantics(tile),
          isSemantics(label: '$seconds seconds'),
        );
      }
    });

    testWidgets('choosing a timer creates that game', (tester) async {
      final service = await _openCreateRoom(tester);

      await tapAndSettle(tester, find.byKey(const ValueKey('answer-time-30')));
      await _create(tester);

      expect(service.createdWith!.answerSeconds, 30);
    });

    testWidgets('offers every round option', (tester) async {
      await _openCreateRoom(tester);

      for (final option in GameSettings.roundOptions) {
        expect(_rounds(option), findsOneWidget);
      }
    });

    testWidgets('choosing rounds and categories creates that game', (
      tester,
    ) async {
      final service = await _openCreateRoom(tester);

      await tapAndSettle(tester, _rounds(5));
      await tapAndSettle(tester, _category(Category.movie));
      await tapAndSettle(tester, _category(Category.brand));
      expect(find.text('Categories (4 of 6)'), findsOneWidget);
      await _create(tester);

      final settings = service.createdWith!;
      expect(settings.rounds, 5);
      expect(settings.categories, [
        Category.animal,
        Category.place,
        Category.person,
        Category.food,
      ]);
    });

    testWidgets('a removed category can be added back', (tester) async {
      final service = await _openCreateRoom(tester);

      await tapAndSettle(tester, _category(Category.food));
      await tapAndSettle(tester, _category(Category.food));
      await _create(tester);

      expect(service.createdWith!.usesEveryCategory, isTrue);
    });

    testWidgets('the last category cannot be removed', (tester) async {
      final service = await _openCreateRoom(tester);

      for (final category in Category.values) {
        await tapAndSettle(tester, _category(category));
      }
      expect(find.text('Categories (1 of 6)'), findsOneWidget);
      await _create(tester);

      expect(service.createdWith!.categories, [Category.brand]);
    });

    testWidgets('categories show as selected to screen readers', (
      tester,
    ) async {
      await _openCreateRoom(tester);

      await tapAndSettle(tester, _category(Category.place));

      expect(
        tester.getSemantics(_category(Category.place)),
        isSemantics(isSelected: false),
      );
      expect(
        tester.getSemantics(_category(Category.animal)),
        isSemantics(isSelected: true),
      );
    });
  });

  group('during the game', () {
    testWidgets('the Lobby shows the settings to everyone', (tester) async {
      await pumpGame(
        tester,
        service: FakeGameService(
          fakeLobby(
            players: [fakePlayer(localId, name: 'Sam', isHost: true)],
            settings: GameSettings(
              rounds: 5,
              categories: const [Category.animal, Category.food],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 rounds · 90s each · 2 categories'), findsOneWidget);
    });

    testWidgets('the Lobby shows a standard game simply', (tester) async {
      await pumpGame(
        tester,
        service: FakeGameService(
          fakeLobby(players: [fakePlayer(localId, name: 'Sam', isHost: true)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 rounds · 90s each · All categories'), findsOneWidget);
    });

    testWidgets('the answer screen only has the chosen categories', (
      tester,
    ) async {
      await pumpGame(
        tester,
        service: FakeGameService(
          fakeAnsweringRoom(
            deadline: clock.now().add(GameRules.answerTime),
            settings: GameSettings(
              categories: const [Category.place, Category.brand],
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(GameTextField), findsOneWidget);
      expect(find.text('Place'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('step-place')), findsOneWidget);
      expect(find.byKey(const ValueKey('step-brand')), findsOneWidget);
      expect(find.byKey(const ValueKey('step-animal')), findsNothing);
      expect(find.text('Round 1 of 3'), findsOneWidget);
    });

    testWidgets('locking in only counts blanks in the chosen categories', (
      tester,
    ) async {
      final service = FakeGameService(
        fakeAnsweringRoom(
          deadline: clock.now().add(GameRules.answerTime),
          settings: GameSettings(
            categories: const [Category.place, Category.brand],
          ),
        ),
      );
      await pumpGame(tester, service: service);
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField), 'Malaysia');
      await tester.tap(find.text('Next'));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextFormField), 'Microsoft');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFrames(tester);
      await tester.ensureVisible(find.text('Lock In Answers'));
      await pumpFrames(tester);
      await tester.tap(find.text('Lock In Answers'));
      await pumpFrames(tester);

      expect(find.textContaining('blank'), findsNothing);
      expect(service.calls, contains('submitAnswers'));
    });

    testWidgets('a blank chosen category is still counted', (tester) async {
      final service = FakeGameService(
        fakeAnsweringRoom(
          deadline: clock.now().add(GameRules.answerTime),
          settings: GameSettings(
            categories: const [Category.place, Category.brand],
          ),
        ),
      );
      await pumpGame(tester, service: service);
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Malaysia');
      await tester.tap(find.text('Next'));
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFrames(tester);
      await tester.ensureVisible(find.text('Lock In Answers'));
      await pumpFrames(tester);
      await tester.tap(find.text('Lock In Answers'));
      await pumpFrames(tester);

      expect(find.text('1 answer is blank'), findsOneWidget);
    });

    testWidgets('the Lobby shows a short timer', (tester) async {
      await pumpGame(
        tester,
        service: FakeGameService(
          fakeLobby(
            players: [fakePlayer(localId, name: 'Sam', isHost: true)],
            settings: GameSettings(rounds: 1, answerSeconds: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 round · 30s each · All categories'), findsOneWidget);
    });

    testWidgets('the countdown starts from the chosen timer', (tester) async {
      final settings = GameSettings(answerSeconds: 30);
      await pumpGame(
        tester,
        service: FakeGameService(
          fakeAnsweringRoom(
            deadline: clock.now().add(settings.answerTime),
            settings: settings,
          ),
        ),
      );
      await pumpFrames(tester);

      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('letter selection shows the round', (tester) async {
      await pumpGame(
        tester,
        service: FakeGameService(fakeLetterRoom(pickerId: localId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Round 1 of 3'), findsOneWidget);
    });
  });
}
