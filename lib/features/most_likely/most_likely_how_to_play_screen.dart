import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';

/// The rules of Most Likely To..., in a few short cards.
class MostLikelyHowToPlayScreen extends StatelessWidget {
  const MostLikelyHowToPlayScreen({super.key});

  static const _steps = [
    (
      Icons.groups_rounded,
      AppColors.sky,
      'Get together',
      'The host creates a room, nearby or online, and 2 to 7 friends tap '
          'Join Room.',
    ),
    (
      Icons.help_rounded,
      AppColors.peach,
      'Read the question',
      'Like "Who is most likely to live on Mars?" Think about your '
          'friends... or yourself!',
    ),
    (
      Icons.how_to_vote_rounded,
      AppColors.lavender,
      'Vote in secret',
      'Tap a face and lock it in. You can vote for yourself. Nobody ever '
          'sees who voted for whom.',
    ),
    (
      Icons.bar_chart_rounded,
      AppColors.mint,
      'See the result',
      'Everyone sees how many votes each player got, and a crown on who is '
          'most likely.',
    ),
    (
      Icons.psychology_rounded,
      AppColors.sunshine,
      'Read the room',
      'Voted for the player who got the most votes? You win 1 point. The '
          'best mind reader wins the game!',
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
