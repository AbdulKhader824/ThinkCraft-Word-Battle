import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/features/validation/validation_screen.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

import '../../fakes.dart';
import '../../helpers.dart';

const _timing = BotTiming();

void main() {
  testWidgets('a whole game runs on the real service, as host', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    await tapAndSettle(tester, buttonLabelled('Create Room'));
    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tapAndSettle(tester, buttonLabelled('Create Room'));
    expect(currentRoute(tester), AppRoutes.lobby);

    await tester.pump(_timing.ready.$2);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Start Game'));
    expect(currentRoute(tester), AppRoutes.letterSelection);

    await tapAndSettle(tester, find.byKey(const ValueKey('letter-M')));
    expect(find.text('The letter is M!'), findsOneWidget);

    await tester.pump(_timing.letterReveal);
    await pumpFrames(tester);
    expect(currentRoute(tester), AppRoutes.answering);

    await tester.pump(GameRules.answerTime);
    await pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(gameService(tester).room!.phase, GamePhase.validating);
    expect(currentRoute(tester), AppRoutes.validation);

    final skip = find.text('Not sure? Skip this one');
    while (skip.evaluate().isNotEmpty) {
      await tester.pump(ValidationScreen.tapGuard);
      await tapAndSettle(tester, skip);
    }
    expect(find.text('Counting the votes...'), findsOneWidget);

    await tester.pump(_timing.voting.$2);
    await tester.pumpAndSettle();
    expect(currentRoute(tester), AppRoutes.results);
    expect(find.text('Round 1 results'), findsOneWidget);

    await tapAndSettle(tester, find.text('Play Again'));
    expect(currentRoute(tester), AppRoutes.letterSelection);
    expect(gameService(tester).room!.round!.number, 2);
    expect(find.textContaining('is choosing the letter'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Back'));
    await tapAndSettle(tester, find.text('Leave Game'));
    expect(currentRoute(tester), AppRoutes.home);
    expect(gameService(tester).room, isNull);
  });

  testWidgets('Return Home from the results clears the game', (tester) async {
    final service = FakeGameService(fakeResultsRoom(scores: const {}));
    await pumpGame(tester, service: service);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Return Home'));

    expect(currentRoute(tester), AppRoutes.home);
  });

  testWidgets('a whole game runs on the real service, as guest', (
    tester,
  ) async {
    await pumpGame(tester);
    await goToHome(tester);

    await tapAndSettle(tester, buttonLabelled('Join Room'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Sam');
    await tester.enterText(find.byType(TextFormField).at(1), 'ABC234');
    await tapAndSettle(tester, buttonLabelled('Join Room'));
    expect(find.text('Start Game'), findsNothing);

    await tester.pump(_timing.ready.$2);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text("I'm Ready"));
    await tester.pump(_timing.hostStart);
    await tester.pumpAndSettle();
    expect(currentRoute(tester), AppRoutes.letterSelection);
    expect(find.textContaining('is choosing the letter'), findsOneWidget);

    await tester.pump(_timing.pickLetter);
    await tester.pumpAndSettle();
    expect(find.textContaining('The letter is'), findsOneWidget);

    await tester.pump(_timing.letterReveal);
    await pumpFrames(tester);
    expect(currentRoute(tester), AppRoutes.answering);
  });

  testWidgets('leaving mid-round stops the game', (tester) async {
    final service = FakeGameService(fakeLetterRoom(pickerId: localId));
    await pumpGame(tester, service: service);
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byTooltip('Back'));
    await tapAndSettle(tester, find.text('Leave Game'));

    expect(currentRoute(tester), AppRoutes.home);
  });
}
