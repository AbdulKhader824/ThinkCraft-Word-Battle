import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/drawing_room.dart';
import '../../models/player.dart';
import '../../services/drawing/drawing_providers.dart';
import '../../services/rules/drawing_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';

/// The leaderboard after each round, and at the end of the game.
class DrawingResultsScreen extends ConsumerStatefulWidget {
  const DrawingResultsScreen({super.key});

  @override
  ConsumerState<DrawingResultsScreen> createState() =>
      _DrawingResultsScreenState();
}

class _DrawingResultsScreenState extends ConsumerState<DrawingResultsScreen> {
  bool _playedFanfare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playedFanfare) return;
    _playedFanfare = true;
    final room = ref.read(drawingRoomProvider);
    final myId = ref.read(drawingServiceProvider).localPlayerId;
    final won = room != null && room.isGameOver && _rankOf(room, myId) == 1;
    playSound(ref, won ? GameSound.win : GameSound.results);
  }

  static int? _rankOf(DrawingRoom room, String? myId) {
    for (final entry in _ranked(room)) {
      if (entry.playerId == myId) return entry.rank;
    }
    return null;
  }

  static List<({String playerId, int rank, int points})> _ranked(
    DrawingRoom room,
  ) {
    return DrawingRules.rank(
      {
        for (final player in room.players)
          player.id: room.scoreOf(player.id).points,
      },
      [for (final player in room.players) player.id],
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(drawingRoomProvider);
    final service = ref.watch(drawingServiceProvider);
    final myId = service.localPlayerId;
    if (room == null || myId == null) return const SizedBox.shrink();

    final ranked = _ranked(room);
    final isHost = room.host.id == myId;

    return LeaveGameGuard(
      leave: service.leaveRoom,
      child: GameFrame(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Entrance(
                        child: _Banner(room: room, ranked: ranked),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final (index, entry) in ranked.indexed) ...[
                        Entrance(
                          index: index + 1,
                          child: _PlayerLine(
                            player: room.playerOrNull(entry.playerId)!,
                            rank: entry.rank,
                            score: room.scoreOf(entry.playerId),
                            isMe: entry.playerId == myId,
                            isAway: room.awayIds.contains(entry.playerId),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: room.isGameOver
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GameButton(
                              label: isHost
                                  ? 'New Game'
                                  : 'Host can start a New Game',
                              icon: Icons.replay_rounded,
                              compact: true,
                              onPressed: isHost ? service.newGame : null,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            GameButton(
                              label: 'Return Home',
                              icon: Icons.home_rounded,
                              style: GameButtonStyle.sky,
                              compact: true,
                              onPressed: service.leaveRoom,
                            ),
                          ],
                        )
                      : _NextRoundPanel(
                          room: room,
                          myId: myId,
                          onReady: service.nextRound,
                        ),
                ),
              ],
            ),
            if (room.isGameOver && _rankOf(room, myId) == 1)
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.room, required this.ranked});

  final DrawingRoom room;
  final List<({String playerId, int rank, int points})> ranked;

  @override
  Widget build(BuildContext context) {
    final leaders = ranked.where((entry) => entry.rank == 1).toList();
    final name = room.playerOrNull(leaders.first.playerId)?.name ?? '';
    final headline = leaders.length > 1
        ? "It's a tie!"
        : room.isGameOver
        ? '$name wins!'
        : '$name is leading!';
    final rounds = room.settings.rounds;
    final subtitle = room.isGameOver
        ? (rounds == 1 ? 'Final results' : 'Final results after $rounds rounds')
        : 'Round ${room.round} of $rounds done';

    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.sunshine,
            size: 56,
          ),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: Colors.white),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({
    required this.player,
    required this.rank,
    required this.score,
    required this.isMe,
    required this.isAway,
  });

  final Player player;
  final int rank;
  final DrawingScore score;
  final bool isMe;
  final bool isAway;

  Color? get _trophy => switch (rank) {
    1 => AppColors.gold,
    2 => AppColors.silver,
    3 => AppColors.bronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final trophy = _trophy;
    return GameCard(
      color: isMe ? AppColors.backgroundMint : AppColors.cream,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                if (trophy != null)
                  Icon(Icons.emoji_events_rounded, color: trophy, size: 24),
                Text('#$rank', style: AppText.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Opacity(
            opacity: isAway ? 0.5 : 1,
            child: PlayerAvatar(index: player.avatarIndex, size: 48),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.name} (you)' : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                if (score.stars > 0)
                  Semantics(
                    label: '${score.stars} times first to guess',
                    excludeSemantics: true,
                    child: Wrap(
                      children: [
                        for (var star = 0; star < score.stars; star++)
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.gold,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                if (isAway) Text('Away', style: AppText.bodySmall),
              ],
            ),
          ),
          Text('${score.points}', style: AppText.heading),
        ],
      ),
    );
  }
}

/// Next Round, with a countdown and every player's face showing whether
/// they are ready.
class _NextRoundPanel extends StatelessWidget {
  const _NextRoundPanel({
    required this.room,
    required this.myId,
    required this.onReady,
  });

  final DrawingRoom room;
  final String myId;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final ready = room.readyIds;
    final iAmReady = ready.contains(myId);
    final waiting = room.players.where((p) => !ready.contains(p.id)).length;
    final deadline = room.deadline;
    final status = !iAmReady
        ? 'Press Next Round when you are ready!'
        : waiting == 1
        ? 'Waiting for 1 more player...'
        : 'Waiting for $waiting more players...';

    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (deadline != null) ...[
                CountdownRing(
                  deadline: deadline,
                  total: DrawingRoom.nextRoundWait,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status, style: AppText.label),
                    Text(
                      'Players not ready in time leave the room.',
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              for (final player in room.players)
                Semantics(
                  label:
                      '${player.id == myId ? 'You' : player.name}, '
                      '${ready.contains(player.id) ? 'ready' : 'waiting'}',
                  excludeSemantics: true,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: ready.contains(player.id) ? 1 : 0.55,
                        child: PlayerAvatar(
                          index: player.avatarIndex,
                          size: 44,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: ready.contains(player.id)
                                ? AppColors.valid
                                : AppColors.sunshine,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            ready.contains(player.id)
                                ? Icons.check_rounded
                                : Icons.hourglass_top_rounded,
                            color: ready.contains(player.id)
                                ? Colors.white
                                : AppColors.navy,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GameButton(
            label: iAmReady ? 'Waiting...' : 'Next Round',
            icon: iAmReady
                ? Icons.hourglass_top_rounded
                : Icons.arrow_forward_rounded,
            compact: true,
            onPressed: iAmReady ? null : onReady,
          ),
        ],
      ),
    );
  }
}
