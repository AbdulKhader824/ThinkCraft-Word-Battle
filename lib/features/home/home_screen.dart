import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/mascot.dart';
import '../../core/widgets/rainbow_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// The buttons arrive one after another, after the title.
  static const _step = Duration(milliseconds: 80);

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Entrance(
            fromScale: 0.6,
            child: Center(child: Mascot(size: 170)),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 1,
            step: _step,
            child: Text(
              AppStrings.brandLine,
              textAlign: TextAlign.center,
              style: AppText.heading,
            ),
          ),
          Entrance(
            index: 2,
            step: _step,
            fromScale: 0.8,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RainbowTitle(
                AppStrings.gameLine,
                style: AppText.display,
                textAlign: TextAlign.center,
                outlineWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Entrance(
            index: 3,
            step: _step,
            child: Text(
              AppStrings.tagline,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Entrance(
            index: 4,
            step: _step,
            child: GameButton(
              label: 'Create Room',
              icon: Icons.add_circle_rounded,
              onPressed: () => context.push(AppRoutes.createRoom),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 5,
            step: _step,
            child: GameButton(
              label: 'Join Room',
              icon: Icons.login_rounded,
              style: GameButtonStyle.sunshine,
              onPressed: () => context.push(AppRoutes.joinRoom),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 6,
            step: _step,
            child: Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: 'How to Play',
                    icon: Icons.menu_book_rounded,
                    style: GameButtonStyle.lavender,
                    compact: true,
                    onPressed: () => context.push(AppRoutes.howToPlay),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GameButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    style: GameButtonStyle.sky,
                    compact: true,
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
