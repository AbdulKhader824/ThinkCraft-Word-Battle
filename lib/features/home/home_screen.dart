import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/mascot.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Mascot(size: 170)),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.brandLine,
            textAlign: TextAlign.center,
            style: AppText.heading,
          ),
          Text(
            AppStrings.gameLine,
            textAlign: TextAlign.center,
            style: AppText.display,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.tagline,
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          GameButton(
            label: 'Create Room',
            icon: Icons.add_circle_rounded,
            onPressed: () => context.push(AppRoutes.createRoom),
          ),
          const SizedBox(height: AppSpacing.md),
          GameButton(
            label: 'Join Room',
            icon: Icons.login_rounded,
            style: GameButtonStyle.sunshine,
            onPressed: () => context.push(AppRoutes.joinRoom),
          ),
        ],
      ),
    );
  }
}
