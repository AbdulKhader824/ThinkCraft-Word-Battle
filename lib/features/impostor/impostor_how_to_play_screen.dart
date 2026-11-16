import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';

/// The rules of The Impostor, in a few short cards.
class ImpostorHowToPlayScreen extends StatelessWidget {
  const ImpostorHowToPlayScreen({super.key});

  static const _steps = [
    (
      Icons.wifi_rounded,
      AppColors.sky,
      'Get together',
      'Sit together, on the same Wi-Fi or the host\'s hotspot. The host '
          'creates a room, and 2 to 7 friends tap Join Room.',
    ),
    (
      Icons.touch_app_rounded,
      AppColors.peach,
      'See your word',
      'Hold the card to see the secret word. One player is the Impostor: '
          'they only see the topic, like Animals.',
    ),
    (
      Icons.record_voice_over_rounded,
      AppColors.mint,
      'Give clues',
      'Take turns saying one clue out loud, then tap Done. Don\'t say the '
          'word! The Impostor has to bluff.',
    ),
    (
      Icons.how_to_vote_rounded,
      AppColors.lavender,
      'Vote',
      'Talk it over, then vote in secret for who you think the Impostor '
          'is. Most votes on them means they\'re caught.',
    ),
    (
      Icons.lightbulb_rounded,
      AppColors.coral,
      'Last chance',
      'Caught or not, the Impostor picks the word from six. A right guess '
          'wins 3 points.',
    ),
    (
      Icons.emoji_events_rounded,
      AppColors.sunshine,
      'Points',
      'Vote for the Impostor: 3 points, and 1 more for everyone if they\'re '
          'caught. The Impostor gets 2 for each player who voted for '
          'someone else, and 3 if not caught.',
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
