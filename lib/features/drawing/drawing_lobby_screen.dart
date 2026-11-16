import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../models/drawing_room.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../services/drawing/drawing_providers.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';
import '../lobby/lobby_screen.dart';

/// Waiting for friends to join a Guess the Drawing room.
class DrawingLobbyScreen extends ConsumerWidget {
  const DrawingLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(drawingRoomProvider);
    final service = ref.watch(drawingServiceProvider);
    final myId = service.localPlayerId;
    ref.listen(drawingRoomProvider, (previous, next) {
      int readyOthers(DrawingRoom? room) => (room?.players ?? const [])
          .where((player) => player.id != myId && player.isReady)
          .length;
      if (readyOthers(next) > readyOthers(previous)) {
        playSound(ref, GameSound.ready);
      }
    });
    final me = room?.playerOrNull(myId);
    if (room == null || myId == null || me == null) {
      return const SizedBox.shrink();
    }

    return LeaveGameGuard(
      leave: service.leaveRoom,
      child: GameScreen(
        title: 'Game Lobby',
        onBack: () => confirmLeaveGame(context, ref, leave: service.leaveRoom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoomCodeCard(
              code: room.code,
              mode: service.isOnline ? RoomMode.online : RoomMode.nearby,
              game: 'Guess the Drawing',
            ),
            if (me.isHost && !service.isOnline) ...[
              const SizedBox(height: AppSpacing.sm),
              InviteCard(address: service.hostAddress),
            ],
            const SizedBox(height: AppSpacing.sm),
            _SettingsSummary(settings: room.settings),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${room.players.length} of ${room.capacity} players',
              textAlign: TextAlign.center,
              style: AppText.label,
            ),
            const SizedBox(height: AppSpacing.xs),
            PlayerGrid(players: room.players, myId: myId),
            const SizedBox(height: AppSpacing.lg),
            _LobbyAction(room: room, me: me),
          ],
        ),
      ),
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({required this.settings});

  final DrawingSettings settings;

  @override
  Widget build(BuildContext context) {
    final rounds = settings.rounds == 1
        ? '1 round'
        : '${settings.rounds} rounds';

    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$rounds · ${settings.drawSeconds}s to draw',
            style: AppText.label,
          ),
          Text(
            'Words: ${settings.wordLevel.label} · Everyone draws once a round',
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LobbyAction extends ConsumerWidget {
  const _LobbyAction({required this.room, required this.me});

  final DrawingRoom room;
  final Player me;

  String get _hint {
    if (!me.isHost) return 'The host starts when everyone is ready.';
    if (room.players.length < 2) return 'Waiting for friends to join...';
    final waiting = room.players.where((player) => !player.isReady).length;
    if (waiting == 0) return 'Everyone is ready!';
    return waiting == 1
        ? 'Waiting for 1 player to get ready.'
        : 'Waiting for $waiting players to get ready.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(drawingServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_hint, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: AppSpacing.sm),
        if (me.isHost)
          GameButton(
            label: 'Start Game',
            icon: Icons.play_arrow_rounded,
            onPressed: room.canStart ? service.startGame : null,
          )
        else
          GameButton(
            label: me.isReady ? 'Not Ready' : "I'm Ready",
            icon: me.isReady ? Icons.close_rounded : Icons.check_circle_rounded,
            style: me.isReady ? GameButtonStyle.coral : GameButtonStyle.mint,
            onPressed: () => service.setReady(!me.isReady),
          ),
      ],
    );
  }
}
