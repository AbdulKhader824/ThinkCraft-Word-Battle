import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/mascot.dart';

/// The Impostor's own start screen, opened from its card in the hub.
class ImpostorHomeScreen extends StatelessWidget {
  const ImpostorHomeScreen({super.key});

  static const tagline = 'One of you doesn\'t know the word. Find them!';

  static const _step = Duration(milliseconds: 80);

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'The Impostor',
      onBack: () => goBackOrHome(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Entrance(
            fromScale: 0.6,
            child: Center(child: Mascot(size: 150)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Entrance(
            index: 1,
            step: _step,
            child: Text(
              tagline,
              textAlign: TextAlign.center,
              style: AppText.heading,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Entrance(
            index: 1,
            step: _step,
            child: Text(
              'Every player uses their own phone, on the same Wi-Fi or '
              'hotspot. Clues are said out loud, so sit together. '
              '3 to 8 players.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Entrance(
            index: 2,
            step: _step,
            child: GameButton(
              label: 'Create Room',
              icon: Icons.add_circle_rounded,
              onPressed: () => context.push(AppRoutes.impostorCreate),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 3,
            step: _step,
            child: GameButton(
              label: 'Join Room',
              icon: Icons.login_rounded,
              style: GameButtonStyle.sunshine,
              onPressed: () => context.push(AppRoutes.impostorJoin),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            index: 4,
            step: _step,
            child: GameButton(
              label: 'How to Play',
              icon: Icons.menu_book_rounded,
              style: GameButtonStyle.lavender,
              compact: true,
              onPressed: () => context.push(AppRoutes.impostorHowToPlay),
            ),
          ),
        ],
      ),
    );
  }
}
