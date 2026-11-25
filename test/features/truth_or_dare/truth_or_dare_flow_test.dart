import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/app.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/truth_or_dare_game.dart';
import 'package:thinkcraft_word_battle/services/truth_or_dare_providers.dart';

import '../../helpers.dart';

TodGame? _game(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ThinkCraftApp)))
        .read(truthOrDareProvider);

Future<void> _addPlayer(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField).first, name);
  await tapAndSettle(tester, find.byKey(const ValueKey('add-player')));
}

/// Opens Truth or Dare and adds [names] on the players screen.
Future<void> _setUp(WidgetTester tester, List<String> names) async {
  await pumpGame(tester);
  await goToHome(tester);
  await openRoute(tester, AppRoutes.truthOrDare);
  await tapAndSettle(tester, buttonLabelled('Play'));
  for (final name in names) {
    await _addPlayer(tester, name);
  }
}

void main() {
  testWidgets('the hub card opens Truth or Dare', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);
    await openRoute(tester, AppRoutes.truthOrDare);

    expect(find.text('Truth or Dare'), findsOneWidget);
    expect(buttonLabelled('Play'), findsOneWidget);
    await tapAndSettle(tester, buttonLabelled('How to Play'));
    expect(find.text('4. Done or Skip'), findsOneWidget);
  });

  testWidgets('players are added and removed; Start needs two', (tester) async {
    await _setUp(tester, ['Sam']);
    expect(find.text('Add 1 more player to start.'), findsOneWidget);

    // The same name twice is turned away.
    await _addPlayer(tester, 'sam');
    expect(find.text('Sam is already playing.'), findsOneWidget);

    await _addPlayer(tester, 'Riya');
    expect(find.text('Who is playing? (2 of 12)'), findsOneWidget);
    expect(find.textContaining('more player'), findsNothing);

    await tapAndSettle(tester, find.byTooltip('Remove Riya'));
    expect(find.text('Who is playing? (1 of 12)'), findsOneWidget);
  });

  testWidgets('a turn: Truth or Dare, no swapping, Done', (tester) async {
    await _setUp(tester, ['Sam', 'Riya', 'Ali']);
    await tester.ensureVisible(find.byKey(const ValueKey('level-teens')));
    await tapAndSettle(tester, find.byKey(const ValueKey('level-teens')));
    await tester.ensureVisible(buttonLabelled('Start'));
    await tapAndSettle(tester, buttonLabelled('Start'));
    expect(currentRoute(tester), AppRoutes.truthOrDarePlay);

    final game = _game(tester)!;
    expect(game.settings.level, TodLevel.teens);
    final player = game.currentPlayer!;
    expect(find.text("${player.name}'s turn!"), findsOneWidget);
    expect(find.text('Round 1 of 5'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Dare'));
    final card = _game(tester)!.card!;
    expect(find.text(card), findsOneWidget);
    expect(find.text('⚡ DARE'), findsOneWidget);

    expect(find.textContaining('Another card'), findsNothing);

    await tapAndSettle(tester, buttonLabelled('Done!'));
    final next = _game(tester)!;
    expect(next.players.firstWhere((p) => p.name == player.name).dares, 1);
    expect(next.currentPlayer!.name, isNot(player.name));
    expect(find.text("${next.currentPlayer!.name}'s turn!"), findsOneWidget);
  });

  testWidgets('three skips and a player is out; the game ends with results', (
    tester,
  ) async {
    await _setUp(tester, ['Sam', 'Riya']);
    await tester.ensureVisible(buttonLabelled('Start'));
    await tapAndSettle(tester, buttonLabelled('Start'));

    // Everyone skips until someone is out, which ends a 2-player game.
    while (currentRoute(tester) == AppRoutes.truthOrDarePlay) {
      await tapAndSettle(tester, buttonLabelled('Truth'));
      expect(find.text('💬 TRUTH'), findsOneWidget);
      final lastLife = _game(tester)!.currentPlayer!.livesLeft == 1;
      await tapAndSettle(
        tester,
        buttonLabelled(lastLife ? 'Skip (last life!)' : 'Skip (lose a life)'),
      );
    }

    expect(currentRoute(tester), AppRoutes.truthOrDareResults);
    expect(find.text('Game over!'), findsOneWidget);
    expect(find.textContaining('· out'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Play Again'));
    expect(currentRoute(tester), AppRoutes.truthOrDarePlay);
    expect(_game(tester)!.players.every((p) => p.livesLeft == 3), isTrue);
  });

  testWidgets('ending early asks first, then shows the scores', (tester) async {
    await _setUp(tester, ['Sam', 'Riya']);
    await tester.ensureVisible(buttonLabelled('Start'));
    await tapAndSettle(tester, buttonLabelled('Start'));
    await tapAndSettle(tester, buttonLabelled('Truth'));
    await tapAndSettle(tester, buttonLabelled('Done!'));

    await tapAndSettle(tester, find.byTooltip('End game'));
    await tapAndSettle(tester, buttonLabelled('Keep Playing'));
    expect(currentRoute(tester), AppRoutes.truthOrDarePlay);

    await tapAndSettle(tester, find.byTooltip('End game'));
    await tapAndSettle(tester, buttonLabelled('End Game'));
    expect(currentRoute(tester), AppRoutes.truthOrDareResults);
    expect(find.textContaining('wins!'), findsOneWidget);
    expect(find.text('Most Honest'), findsOneWidget);

    await tapAndSettle(tester, buttonLabelled('Return Home'));
    expect(_game(tester), isNull);
  });

  testWidgets('the spinner lands on the player before they choose', (
    tester,
  ) async {
    await _setUp(tester, ['Sam', 'Riya', 'Ali']);
    // Motion on from here: the hub's crown would never let the test settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures();
    await tester.ensureVisible(buttonLabelled('Start'));
    await tester.tap(buttonLabelled('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // While spinning, Truth and Dare can't be tapped yet.
    final hidden = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('turn-name')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(hidden.ignoring, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    final player = _game(tester)!.currentPlayer!;
    expect(find.text("${player.name}'s turn!"), findsOneWidget);
    await tester.tap(buttonLabelled('Truth'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('💬 TRUTH'), findsOneWidget);
  });
}
