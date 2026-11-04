import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'outlined_text.dart';

/// A playful title where each letter has its own candy colour and a thick
/// navy outline, like letters cut from coloured paper.
///
/// It is one piece of text, so screen readers and tests read it normally.
class RainbowTitle extends StatelessWidget {
  const RainbowTitle(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.outlineWidth = 2.5,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double outlineWidth;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppText.title;
    var colour = 0;

    return OutlinedText.rich(
      TextSpan(
        children: [
          for (final character in text.characters)
            TextSpan(
              text: character,
              style: character.trim().isEmpty
                  ? null
                  : TextStyle(
                      color: AppColors.candy[colour++ % AppColors.candy.length],
                    ),
            ),
        ],
      ),
      style: base,
      textAlign: textAlign,
      outlineWidth: outlineWidth,
      dropShadow: true,
    );
  }
}
