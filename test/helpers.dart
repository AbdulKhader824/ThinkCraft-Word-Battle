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

/// Starts the app at a phone-sized screen with animations reduced, because
/// endless animations would stop pumpAndSettle from ever finishing.
///
/// Uses a seeded [LocalGameService] unless a [service] is given.
Future<void> pumpGame(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  GameService? service,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameServiceProvider.overrideWith((ref) {
          final game = service ?? LocalGameService(random: Random(1));
          ref.onDispose(game.dispose);
          return game;
        }),
      ],
      child: const ThinkCraftApp(),
    ),
  );
  await tester.pump();
}

/// Waits for the splash screen to finish and lands on Home.
Future<void> goToHome(WidgetTester tester) async {
  await tester.pump(SplashScreen.displayTime);
  await tester.pumpAndSettle();
}

/// Scrolls a widget into view, then taps it.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
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

/// The address the app is currently showing.
String currentRoute(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThinkCraftApp)),
  );
  final GoRouter router = container.read(routerProvider);
  return router.state.matchedLocation;
}
