import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thinkcraft_word_battle/app/app.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/features/home/splash_screen.dart';
import 'package:thinkcraft_word_battle/services/game_providers.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/profile_store.dart';
import 'package:thinkcraft_word_battle/services/sound_service.dart';

import 'fakes.dart';

/// Starts the app at a phone-sized screen with animations reduced, because
/// endless animations would stop pumpAndSettle from ever finishing.
///
/// Uses a seeded [LocalGameService] unless a [service] is given, and an
/// in-memory profile unless [profiles] is given.
Future<void> pumpGame(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  GameService? service,
  ProfileStore? profiles,
  FakeSoundPlayer? sounds,
  double textScale = 1,
  bool reduceMotion = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameServiceProvider.overrideWith((ref) {
          final game = service ?? LocalGameService(random: Random(1));
          ref.onDispose(game.dispose);
          return game;
        }),
        profileStoreProvider.overrideWithValue(
          profiles ?? MemoryProfileStore(),
        ),
        // Tests never play real audio; they record what would have played.
        soundPlayerProvider.overrideWithValue(sounds ?? FakeSoundPlayer()),
      ],
      child: const ThinkCraftApp(),
    ),
  );
  await tester.pump();
}

/// Waits for the splash screen to finish and lands on the game hub.
Future<void> goToHome(WidgetTester tester) async {
  await tester.pump(SplashScreen.displayTime);
  await tester.pumpAndSettle();
}

/// Goes from the hub into Word Battle, where Create and Join Room are.
Future<void> goToWordBattle(WidgetTester tester) async {
  await goToHome(tester);
  await tapAndSettle(tester, buttonLabelled('Play'));
}

/// Scrolls a widget into view, then taps it.
///
/// Typing leaves a text field focused, and Flutter keeps scrolling a focused
/// field back into view, which would undo the scroll to [finder]. Clearing
/// focus first is what dismissing the keyboard does on a phone.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets a countdown ring screen move on. Its repeating update never settles,
/// so pumpAndSettle can't be used there.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder buttonLabelled(String label) {
  return find.widgetWithText(InkWell, label);
}

GameService gameService(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThinkCraftApp)),
  );
  return container.read(gameServiceProvider);
}

/// Opens [route] on top of the current screen, as a button would.
Future<void> openRoute(WidgetTester tester, String route) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThinkCraftApp)),
  );
  container.read(routerProvider).push(route);
  await tester.pumpAndSettle();
}

/// The address the app is currently showing.
String currentRoute(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThinkCraftApp)),
  );
  final GoRouter router = container.read(routerProvider);
  return router.state.matchedLocation;
}
