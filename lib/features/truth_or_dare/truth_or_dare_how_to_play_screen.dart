import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';

/// The rules of Truth or Dare, in a few short cards.
class TruthOrDareHowToPlayScreen extends StatelessWidget {
  const TruthOrDareHowToPlayScreen({super.key});

  static const _steps = [
    (
      Icons.groups_rounded,
      AppColors.sky,
      'Sit in a circle',
      'Type everyone\'s name. One phone gets passed around.',
    ),
    (
      Icons.autorenew_rounded,
      AppColors.peach,
      'Spin',
      'The spinner picks a player. Everyone gets one turn each round.',
    ),
    (
      Icons.help_rounded,
      AppColors.lavender,
      'Truth or Dare?',
      'Pick Truth to answer a question out loud, or Dare to do something '
          'funny. Don\'t like the card? Tap Another card, for free.',
    ),
    (
      Icons.check_circle_rounded,
      AppColors.mint,
      'Done or Skip',
      'Did it? Tap Done for a point. Skip costs a life: everyone has 3, and '
          'after 3 skips you\'re out.',
    ),
    (
      Icons.emoji_events_rounded,
      AppColors.sunshine,
      'Win',
      'Most points wins. There are awards for the Bravest (most dares) and '
          'the Most Honest (most truths).',
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
