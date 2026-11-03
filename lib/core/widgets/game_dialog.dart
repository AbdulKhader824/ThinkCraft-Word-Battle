import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'game_button.dart';

/// Asks a yes or no question. Returns true only if the player confirms.
Future<bool> showGameConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.center, style: AppText.heading),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
            GameButton(
              label: confirmLabel,
              style: GameButtonStyle.coral,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
