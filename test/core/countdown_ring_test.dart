import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/theme/app_colors.dart';
import 'package:thinkcraft_word_battle/core/widgets/countdown_ring.dart';

/// The ring's colour with [left] remaining of a [total]-second timer.
Future<Color> _colorWith(
  WidgetTester tester, {
  required int total,
  required int left,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: CountdownRing(
          deadline: clock.now().add(Duration(seconds: left)),
          total: Duration(seconds: total),
        ),
      ),
    ),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(CountdownRing),
      matching: find.byType(CustomPaint),
    ),
  );
  // The painter is private, so its colour is read without its type.
  final color = (paint.painter as dynamic).color as Color;

  // Remove the ring so its repeating timer stops before the test ends.
  await tester.pumpWidget(const SizedBox.shrink());
  return color;
}

void main() {
  group('a 90-second timer', () {
    testWidgets('is mint with plenty of time', (tester) async {
      expect(await _colorWith(tester, total: 90, left: 31), AppColors.mintDeep);
    });

    testWidgets('turns yellow at 30 seconds', (tester) async {
      expect(
        await _colorWith(tester, total: 90, left: 30),
        AppColors.sunshineDeep,
      );
    });

    testWidgets('turns red at 10 seconds', (tester) async {
      expect(
        await _colorWith(tester, total: 90, left: 10),
        AppColors.coralDeep,
      );
    });
  });

  group('a 30-second timer', () {
    testWidgets('starts mint, not yellow', (tester) async {
      expect(await _colorWith(tester, total: 30, left: 30), AppColors.mintDeep);
    });

    testWidgets('turns yellow at 10 seconds', (tester) async {
      expect(
        await _colorWith(tester, total: 30, left: 10),
        AppColors.sunshineDeep,
      );
    });

    testWidgets('turns red at 4 seconds', (tester) async {
      expect(
        await _colorWith(tester, total: 30, left: 5),
        isNot(AppColors.coralDeep),
      );
      expect(await _colorWith(tester, total: 30, left: 4), AppColors.coralDeep);
    });
  });
}
