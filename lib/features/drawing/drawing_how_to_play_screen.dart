import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';

/// The rules of Guess the Drawing, in a few short cards.
class DrawingHowToPlayScreen extends StatelessWidget {
  const DrawingHowToPlayScreen({super.key});

  static const _steps = [
    (
      Icons.wifi_rounded,
      AppColors.sky,
      'Get together',
      'Everyone joins the same Wi-Fi or the host\'s hotspot. The host '
          'creates a room, and friends tap Join Room on their own phones.',
    ),
    (
      Icons.style_rounded,
      AppColors.peach,
      'Pick a word',
      'On your turn you get three words. Pick one. Only you can see it!',
    ),
    (
      Icons.brush_rounded,
      AppColors.mint,
      'Draw it',
      'Draw the word on your phone. Everyone sees your drawing as you '
          'draw. No letters or numbers!',
    ),
    (
      Icons.keyboard_rounded,
      AppColors.lavender,
      'Guess fast',
      'Type your guesses. "So close!" means you are one letter off. '
          'Letters of the word appear as time runs out.',
    ),
    (
      Icons.emoji_events_rounded,
      AppColors.sunshine,
      'Win points',
      'The first right guess gets 10 points and a star, then 8, 6, 5, 4 '
          'and 3. The drawer gets 3 for each player who guesses it, and 2 '
          'more if everyone does.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'How to Play',
      onBack: () => goBackOrHome(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (icon, colour, title, text))
              in _steps.indexed) ...[
            Entrance(
              index: index,
              child: GameCard(
                color: colour,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.navy, size: 36),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${index + 1}. $title', style: AppText.heading),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(text, style: AppText.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
