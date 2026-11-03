import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles for the game.
///
/// Fredoka is used for headings and buttons, and Nunito for body text. Both
/// are variable fonts, so each style sets [TextStyle.fontVariations] to pick
/// the weight that is actually drawn.
abstract final class AppText {
  static const _heading = 'Fredoka';
  static const _body = 'Nunito';

  static TextStyle _style(
    String family,
    double size,
    int weight, {
    double? height,
    Color color = AppColors.navy,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: height,
      color: color,
    );
  }

  static final display = _style(_heading, 44, 700, height: 1.05);
  static final title = _style(_heading, 30, 700, height: 1.15);
  static final heading = _style(_heading, 22, 600, height: 1.2);
  static final button = _style(_heading, 22, 600, height: 1.1);
  static final label = _style(_heading, 18, 600, height: 1.2);
  static final body = _style(_body, 17, 700, height: 1.35);
  static final bodySmall = _style(_body, 15, 700, height: 1.35);
  static final input = _style(_body, 20, 800, height: 1.25);

  static final textTheme = TextTheme(
    displayLarge: display,
    headlineLarge: title,
    headlineMedium: heading,
    titleLarge: heading,
    titleMedium: label,
    bodyLarge: body,
    bodyMedium: bodySmall,
    labelLarge: button,
  );
}
