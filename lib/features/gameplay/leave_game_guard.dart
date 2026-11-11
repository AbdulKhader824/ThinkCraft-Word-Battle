import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/game_dialog.dart';
import '../../services/game_providers.dart';

/// Asks before leaving, then leaves the room. The router notices the room
/// has gone and takes the player home.
///
/// [leave] leaves another game's room; by default it's Word Battle's.
Future<void> confirmLeaveGame(
  BuildContext context,
  WidgetRef ref, {
  Future<void> Function()? leave,
}) async {
  final leaveRoom = leave ?? ref.read(gameServiceProvider).leaveRoom;
  final confirmed = await showGameConfirm(
    context,
    title: 'Leave the game?',
    message: 'You will leave this room and lose your progress.',
    confirmLabel: 'Leave Game',
    cancelLabel: 'Keep Playing',
  );
  if (confirmed) await leaveRoom();
}

/// Catches the phone's back button, so a game can't end by accident.
class LeaveGameGuard extends ConsumerWidget {
  const LeaveGameGuard({super.key, required this.child, this.leave});

  final Widget child;

  /// Leaves another game's room; by default it's Word Battle's.
  final Future<void> Function()? leave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeaveGame(context, ref, leave: leave);
      },
      child: child,
    );
  }
}
