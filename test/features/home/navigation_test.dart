import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/constants/app_constants.dart';
import 'package:thinkcraft_word_battle/features/home/splash_screen.dart';
import 'package:thinkcraft_word_battle/features/home/word_battle_screen.dart';
import 'package:thinkcraft_word_battle/features/hub/hub_screen.dart';
import 'package:thinkcraft_word_battle/features/lobby/create_room_screen.dart';
import 'package:thinkcraft_word_battle/features/lobby/join_room_screen.dart';

import '../../helpers.dart';

void main() {
  testWidgets('splash shows the brand, then moves to the hub', (tester) async {
    await pumpGame(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.tagline), findsOneWidget);

    await goToHome(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HubScreen), findsOneWidget);
  });

  testWidgets('Play opens Word Battle, and Back returns', (tester) async {
    await pumpGame(tester);
    await goToWordBattle(tester);
    expect(find.byType(WordBattleScreen), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.byType(HubScreen), findsOneWidget);
  });

  testWidgets('Word Battle opens Create Room, and Back returns', (
    tester,
  ) async {
    await pumpGame(tester);
    await goToWordBattle(tester);

    await tapAndSettle(tester, buttonLabelled('Create Room'));
    expect(find.byType(CreateRoomScreen), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.byType(WordBattleScreen), findsOneWidget);
    expect(find.byType(CreateRoomScreen), findsNothing);
  });

  testWidgets('Word Battle opens Join Room, and Back returns', (tester) async {
    await pumpGame(tester);
    await goToWordBattle(tester);

    await tapAndSettle(tester, buttonLabelled('Join Room'));
    expect(find.byType(JoinRoomScreen), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(find.byType(WordBattleScreen), findsOneWidget);
    expect(find.byType(JoinRoomScreen), findsNothing);
  });

  testWidgets('the hub opens Settings', (tester) async {
    await pumpGame(tester);
    await goToHome(tester);

    await tapAndSettle(tester, find.byTooltip('Settings'));
    expect(currentRoute(tester), AppRoutes.settings);
  });

  for (final size in const [Size(320, 568), Size(430, 932)]) {
    testWidgets('every screen fits at ${size.width.toInt()}px', (tester) async {
      // Any layout overflow fails the test automatically.
      await pumpGame(tester, size: size);
      await goToWordBattle(tester);

      await tapAndSettle(tester, buttonLabelled('Create Room'));
      await tapAndSettle(tester, find.byTooltip('Back'));
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.byType(JoinRoomScreen), findsOneWidget);
    });
  }
}
