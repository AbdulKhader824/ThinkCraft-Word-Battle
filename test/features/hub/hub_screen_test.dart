import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/features/hub/game_catalog.dart';
import 'package:thinkcraft_word_battle/services/sound_service.dart';

import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  group('game catalog', () {
    test('has 15 games with unique ids', () {
      final ids = GameCatalog.games.map((game) => game.id).toSet();
      expect(GameCatalog.games, hasLength(15));
      expect(ids, hasLength(15));
    });

    test('Word Battle comes first and is the only playable game', () {
      expect(GameCatalog.games.first.name, 'Word Battle');
      expect(
        GameCatalog.games.where((game) => game.isPlayable).map((g) => g.id),
        ['word_battle'],
      );
    });

    test('every game has a bundled picture', () {
      for (final game in GameCatalog.games) {
        expect(File(game.picture).existsSync(), isTrue, reason: game.picture);
      }
    });
  });

  testWidgets('starts on Word Battle, ready to play', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    expect(find.text('Word Battle'), findsOneWidget);
    expect(buttonLabelled('Play'), findsOneWidget);
    expect(find.text('Every player uses their phone'), findsOneWidget);
  });

  testWidgets('swiping shows a game that is coming soon', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.text('Guess the Drawing'), findsOneWidget);
    expect(buttonLabelled('Play'), findsNothing);

    final soon = tester.widget<InkWell>(buttonLabelled('Coming soon'));
    expect(soon.onTap, isNull, reason: 'Coming soon games cannot start');
  });

  testWidgets('each game that slides in plays a flick', (tester) async {
    final sounds = FakeSoundPlayer();
    await pumpGame(tester, sounds: sounds);
    await goToHome(tester);

    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(sounds.played, [GameSound.swipe, GameSound.swipe]);
  });

  testWidgets('tapping the middle card plays it', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    await tester.tap(find.bySemanticsLabel('Word Battle').first);
    await tester.pumpAndSettle();

    expect(currentRoute(tester), AppRoutes.wordBattle);
  });

  testWidgets('one-phone games say so', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    final truthOrDare = GameCatalog.games.indexWhere(
      (game) => game.id == 'truth_or_dare',
    );
    for (var swipe = 0; swipe < truthOrDare; swipe++) {
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();
    }

    expect(find.text('Truth or Dare'), findsOneWidget);
    expect(find.text('Just one phone needed'), findsOneWidget);
  });
}
