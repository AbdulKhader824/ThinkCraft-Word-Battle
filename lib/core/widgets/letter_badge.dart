import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// A chunky mint tile showing the round's letter.
class LetterBadge extends StatelessWidget {
  const LetterBadge({super.key, required this.letter, this.size = 72});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Letter $letter',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(AppRadius.small + size * 0.05),
          boxShadow: [
            BoxShadow(
              color: AppColors.mintDeep,
              offset: Offset(0, size * 0.07),
            ),
          ],
        ),
        // Already huge, and sized to its tile, so system text size is ignored.
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: AppText.display.copyWith(fontSize: size * 0.6, height: 1),
        ),
      ),
    );
  }
}
