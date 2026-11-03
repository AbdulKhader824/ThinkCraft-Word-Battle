import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/theme/app_colors.dart';

/// The WCAG contrast ratio between two colours, from 1:1 up to 21:1.
double contrastRatio(Color a, Color b) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  double luminance(Color color) {
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  final lighter = max(luminance(a), luminance(b));
  final darker = min(luminance(a), luminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const normalText = 4.5;

  test('the contrast formula matches known values', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  // Every text and background pair the app uses. All must pass the normal
  // text level, even where the text happens to be large.
  const pairs = <String, (Color, Color)>{
    'navy on mint': (AppColors.navy, AppColors.mint),
    'navy on sky': (AppColors.navy, AppColors.sky),
    'navy on sunshine': (AppColors.navy, AppColors.sunshine),
    'navy on coral': (AppColors.navy, AppColors.coral),
    'navy on lavender': (AppColors.navy, AppColors.lavender),
    'navy on peach': (AppColors.navy, AppColors.peach),
    'navy on the background': (AppColors.navy, AppColors.background),
    'navy on the mint background': (AppColors.navy, AppColors.backgroundMint),
    'navy on white cards': (AppColors.navy, AppColors.surface),
    'navy on the disabled grey': (AppColors.navy, AppColors.disabled),
    'hint text on the background': (AppColors.navySoft, AppColors.background),
    'hint text on white': (AppColors.navySoft, AppColors.surface),
    'disabled button text': (AppColors.disabledText, AppColors.disabled),
    'error text on white cards': (AppColors.invalid, AppColors.surface),
    'white on navy': (Colors.white, AppColors.navy),
    'sunshine on navy': (AppColors.sunshine, AppColors.navy),
    'white on the Valid green': (Colors.white, AppColors.valid),
    'white on the Invalid red': (Colors.white, AppColors.invalid),
  };

  pairs.forEach((name, colors) {
    test('$name reaches 4.5:1', () {
      final (text, background) = colors;
      expect(contrastRatio(text, background), greaterThanOrEqualTo(normalText));
    });
  });

  for (final (index, tint) in AppColors.avatarTints.indexed) {
    test('avatar tint $index is pale enough behind dark artwork', () {
      expect(contrastRatio(AppColors.navy, tint), greaterThanOrEqualTo(10));
    });
  }
}
