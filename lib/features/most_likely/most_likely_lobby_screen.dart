import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../models/most_likely_room.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../services/most_likely/most_likely_providers.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';
import '../lobby/lobby_screen.dart';

/// Waiting for friends to join a Most Likely To... room.
class MostLikelyLobbyScreen extends ConsumerWidget {
  const MostLikelyLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(mostLikelyRoomProvider);
    final service = ref.watch(mostLikelyServiceProvider);
    final myId = service.localPlayerId;
    ref.listen(mostLikelyRoomProvider, (previous, next) {
      int readyOthers(MostLikelyRoom? room) => (room?.players ?? const [])
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
              game: 'Most Likely To...',
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

  final MostLikelySettings settings;

  @override
  Widget build(BuildContext context) {
    final topics = settings.topics.length == MostLikelyTopic.values.length
        ? 'All topics'
        : [
            for (final topic in MostLikelyTopic.values)
              if (settings.topics.contains(topic)) topic.label,
          ].join(', ');

    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${settings.questions} questions · a leaderboard every '
            '${MostLikelySettings.questionsPerRound}',
            style: AppText.label,
          ),
          Text(topics, style: AppText.bodySmall),
        ],
      ),
    );
  }
}

class _LobbyAction extends ConsumerWidget {
  const _LobbyAction({required this.room, required this.me});

  final MostLikelyRoom room;
  final Player me;

  String get _hint {
    if (!me.isHost) return 'The host starts when everyone is ready.';
    final missing = MostLikelyRoom.minPlayers - room.players.length;
    if (missing > 0) {
      return missing == 1
          ? 'Waiting for 1 more friend to join...'
          : 'Waiting for $missing more friends to join...';
    }
    final waiting = room.players.where((player) => !player.isReady).length;
    if (waiting == 0) return 'Everyone is ready!';
    return waiting == 1
        ? 'Waiting for 1 player to get ready.'
        : 'Waiting for $waiting players to get ready.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(mostLikelyServiceProvider);

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
