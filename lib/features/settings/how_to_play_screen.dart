import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/letter_badge.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/category.dart';
import '../gameplay/category_picture.dart';

/// The rules in five short, illustrated steps, written for ages 7-16.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'How to Play',
      onBack: () => goBackOrHome(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            number: 1,
            color: AppColors.mint,
            title: 'Make a room',
            text:
                'Create a room, or join one with a code. '
                'Play with 2 to 8 players. The host picks how many rounds '
                'and which categories.',
            picture: _PlayersPicture(),
          ),
          _Step(
            number: 2,
            color: AppColors.sky,
            title: 'Pick a letter',
            text: 'One player picks a letter. Everyone gets the same one.',
            picture: LetterBadge(letter: 'M', size: 56),
          ),
          _Step(
            number: 3,
            color: AppColors.sunshine,
            title: 'Think fast!',
            text:
                'The host picks a timer of 30, 60 or 90 seconds. Before it '
                'runs out, write a word for each category, like an animal '
                'or a food, that starts with the letter.',
            picture: _CategoriesPicture(),
          ),
          _Step(
            number: 4,
            color: AppColors.lavender,
            title: 'Vote',
            text:
                "Answers have no names on them. Tap Correct if it's right, "
                "or Incorrect if it isn't.",
            picture: _VotePicture(),
          ),
          _Step(
            number: 5,
            color: AppColors.coral,
            title: 'Score points',
            text:
                'Only you thought of it: 10 points. '
                'Shared with 1 friend: 5 each. '
                'Wrong or empty: 0. '
                'Vote with most players: +1. Vote against them: -1.',
            picture: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.navy,
              size: 48,
            ),
          ),
          _Tip(),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.color,
    required this.title,
    required this.text,
    required this.picture,
  });

  final int number;
  final Color color;
  final String title;
  final String text;
  final Widget picture;

  @override
  Widget build(BuildContext context) {
    // The steps arrive one after another, in reading order.
    return Entrance(
      index: number,
      step: const Duration(milliseconds: 90),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: GameCard(
          color: color,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.navy,
                    child: Text(
                      '$number',
                      style: AppText.label.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(title, style: AppText.heading)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(child: picture),
              const SizedBox(height: AppSpacing.sm),
              Text(text, style: AppText.body),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayersPicture extends StatelessWidget {
  const _PlayersPicture();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.xs,
      children: [
        PlayerAvatar(index: 0, size: 48),
        PlayerAvatar(index: 1, size: 48),
        PlayerAvatar(index: 6, size: 48),
        PlayerAvatar(index: 7, size: 48),
      ],
    );
  }
}

class _CategoriesPicture extends StatelessWidget {
  const _CategoriesPicture();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in Category.values)
          CategoryPicture(
            category: category,
            height: 48,
            semanticLabel: category.label,
          ),
      ],
    );
  }
}

class _VotePicture extends StatelessWidget {
  const _VotePicture();

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: AppText.label.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _chip('Correct', Icons.check_circle_rounded, AppColors.valid),
        _chip('Incorrect', Icons.cancel_rounded, AppColors.invalid),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip();

  @override
  Widget build(BuildContext context) {
    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: AppColors.sunshine,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Tip: unusual answers score more, because nobody else '
              'thinks of them!',
              style: AppText.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
