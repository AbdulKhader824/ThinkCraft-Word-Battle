import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/game_settings.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../services/game_providers.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';
import '../gameplay/leave_game_guard.dart';
import 'ready_badge.dart';
import 'room_form_widgets.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(gameRoomProvider);
    final myId = ref.watch(gameServiceProvider).localPlayerId;
    ref.listen(gameRoomProvider, (previous, next) {
      int readyOthers(Room? room) => (room?.players ?? const [])
          .where((player) => player.id != myId && player.isReady)
          .length;
      if (readyOthers(next) > readyOthers(previous)) {
        playSound(ref, GameSound.ready);
      }
    });
    if (room == null || myId == null) return const SizedBox.shrink();

    return LeaveGameGuard(
      child: GameScreen(
        title: 'Game Lobby',
        onBack: () => confirmLeaveGame(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoomCodeCard(code: room.code),
            const SizedBox(height: AppSpacing.sm),
            _SettingsSummary(settings: room.settings),
            const SizedBox(height: AppSpacing.md),
            _PlayerGrid(players: room.players, myId: myId),
            const SizedBox(height: AppSpacing.lg),
            _LobbyAction(room: room, me: room.playerById(myId)),
          ],
        ),
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final onNavy = AppText.bodySmall.copyWith(color: Colors.white);

    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text('Room code', style: onNavy),
          Text(
            code,
            style: AppText.title.copyWith(
              color: AppColors.sunshine,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const PracticeModeChip(),
        ],
      ),
    );
  }
}

/// Shows everyone the host's choices before the game starts.
class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({required this.settings});

  final GameSettings settings;

  @override
  Widget build(BuildContext context) {
    final rounds = settings.rounds == 1
        ? '1 round'
        : '${settings.rounds} rounds';
    final categories = settings.usesEveryCategory
        ? 'All categories'
        : '${settings.categories.length} categories';

    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$rounds · ${settings.answerSeconds}s each · $categories',
            style: AppText.label,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final category in settings.categories)
                SvgPicture.asset(
                  category.character,
                  width: 32,
                  height: 32,
                  semanticsLabel: category.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  const _PlayerGrid({required this.players, required this.myId});

  static const _colors = [
    AppColors.mint,
    AppColors.sky,
    AppColors.sunshine,
    AppColors.coral,
    AppColors.lavender,
    AppColors.peach,
  ];

  final List<Player> players;
  final String myId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.xs) / 2;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (index, player) in players.indexed)
              SizedBox(
                width: width,
                child: _PlayerCard(
                  player: player,
                  isMe: player.id == myId,
                  color: _colors[index % _colors.length],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isMe,
    required this.color,
  });

  final Player player;
  final bool isMe;
  final Color color;

  String get _role {
    if (player.isHost) return isMe ? 'Host (you)' : 'Host';
    return isMe ? 'You' : 'Player';
  }

  @override
  Widget build(BuildContext context) {
    return GameCard(
      color: color,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          PlayerAvatar(index: player.avatarIndex, size: 52),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                Row(
                  children: [
                    if (player.isHost) ...[
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.navy,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Flexible(
                      child: Text(
                        _role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall,
                      ),
                    ),
                  ],
                ),
                ReadyBadge(isReady: player.isReady),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyAction extends ConsumerWidget {
  const _LobbyAction({required this.room, required this.me});

  final Room room;
  final Player me;

  String get _hint {
    if (!me.isHost) return 'The host starts when everyone is ready.';

    final waiting = room.players.where((player) => !player.isReady).length;
    if (waiting == 0) return 'Everyone is ready!';
    return waiting == 1
        ? 'Waiting for 1 player to get ready.'
        : 'Waiting for $waiting players to get ready.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(gameServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_hint, textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: AppSpacing.sm),
        if (me.isHost)
          GameButton(
            label: 'Start Game',
            icon: Icons.play_arrow_rounded,
            onPressed: room.canStart ? service.startRound : null,
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
