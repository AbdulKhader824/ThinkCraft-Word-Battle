import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/mascot.dart';
import '../../services/game_providers.dart';
import '../gameplay/leave_game_guard.dart';

/// Stands in for the screens that arrive in Phase 3.
class PhasePlaceholderScreen extends ConsumerWidget {
  const PhasePlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LeaveGameGuard(
      child: GameScreen(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Mascot(size: 150)),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.xl),
            GameButton(
              label: 'Return Home',
              icon: Icons.home_rounded,
              onPressed: ref.read(gameServiceProvider).leaveRoom,
            ),
          ],
        ),
      ),
    );
  }
}
