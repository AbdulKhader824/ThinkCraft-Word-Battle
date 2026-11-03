import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/game_dialog.dart';
import '../../services/game_providers.dart';

/// Asks before leaving, then leaves the room. The router notices the room
/// has gone and takes the player home.
Future<void> confirmLeaveGame(BuildContext context, WidgetRef ref) async {
  final service = ref.read(gameServiceProvider);
  final leave = await showGameConfirm(
    context,
    title: 'Leave the game?',
    message: 'You will leave this room and lose your progress.',
    confirmLabel: 'Leave Game',
    cancelLabel: 'Keep Playing',
  );
  if (leave) await service.leaveRoom();
}

/// Catches the phone's back button, so a game can't end by accident.
class LeaveGameGuard extends ConsumerWidget {
  const LeaveGameGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveGame(context, ref);
      },
      child: child,
    );
  }
}
