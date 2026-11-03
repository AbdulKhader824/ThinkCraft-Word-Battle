import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/app.dart';
import 'package:thinkcraft_word_battle/features/home/splash_screen.dart';

/// Starts the app at a phone-sized screen with animations reduced, because
/// Tilo's endless floating would stop pumpAndSettle from ever finishing.
Future<void> pumpGame(
  WidgetTester tester, {
  Size size = const Size(360, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(const ProviderScope(child: ThinkCraftApp()));
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

Finder buttonLabelled(String label) {
  return find.widgetWithText(InkWell, label);
}
