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
import '../../models/most_likely_room.dart';
import '../../models/player.dart';
import '../../services/most_likely/most_likely_providers.dart';
import '../../services/rules/drawing_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';

/// The leaderboard every few questions, with Next Round; after the last
/// question, the winner and everyone's titles.
class MostLikelyResultsScreen extends ConsumerStatefulWidget {
  const MostLikelyResultsScreen({super.key});

  @override
  ConsumerState<MostLikelyResultsScreen> createState() =>
      _MostLikelyResultsScreenState();
}

class _MostLikelyResultsScreenState
    extends ConsumerState<MostLikelyResultsScreen> {
  bool _playedFanfare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playedFanfare) return;
    _playedFanfare = true;
    final room = ref.read(mostLikelyRoomProvider);
    final myId = ref.read(mostLikelyServiceProvider).localPlayerId;
    final won = room != null && room.isGameOver && _rankOf(room, myId) == 1;
    playSound(ref, won ? GameSound.win : GameSound.results);
  }

  static int? _rankOf(MostLikelyRoom room, String? myId) {
    for (final entry in _ranked(room)) {
      if (entry.playerId == myId) return entry.rank;
    }
    return null;
  }

  static List<({String playerId, int rank, int points})> _ranked(
    MostLikelyRoom room,
  ) {
    return DrawingRules.rank(
      {for (final player in room.players) player.id: room.scoreOf(player.id)},
      [for (final player in room.players) player.id],
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(mostLikelyRoomProvider);
    final service = ref.watch(mostLikelyServiceProvider);
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
                      if (room.isGameOver)
                        Entrance(
                          child: _WinnerBanner(room: room, ranked: ranked),
                        )
                      else
                        Entrance(
                          child: Text(
                            'Round ${room.round} of ${room.settings.rounds}',
                            textAlign: TextAlign.center,
                            style: AppText.title,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        room.isGameOver ? 'Final scores' : 'Mind readers',
                        style: AppText.heading,
                      ),
                      Text(
                        '1 point each time you voted for who got the most '
                        'votes.',
                        style: AppText.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final (index, entry) in ranked.indexed) ...[
                        Entrance(
                          index: index + 1,
                          child: _PlayerLine(
                            player: room.playerOrNull(entry.playerId)!,
                            rank: entry.rank,
                            points: entry.points,
                            won: room.roundPoints[entry.playerId],
                            isMe: entry.playerId == myId,
                            isAway: room.awayIds.contains(entry.playerId),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      if (room.isGameOver) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Entrance(
                          index: ranked.length + 1,
                          child: _Titles(room: room, myId: myId),
                        ),
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

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.room, required this.ranked});

  final MostLikelyRoom room;
  final List<({String playerId, int rank, int points})> ranked;

  @override
  Widget build(BuildContext context) {
    final leaders = ranked.where((entry) => entry.rank == 1).toList();
    final name = room.playerOrNull(leaders.first.playerId)?.name ?? '';
    final headline = leaders.length > 1 ? "It's a tie!" : '$name wins!';

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
            key: const ValueKey('winner'),
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: Colors.white),
          ),
          Text(
            'The best mind reader after ${room.settings.questions} questions',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Every player's titles: the questions they were voted most likely for.
class _Titles extends StatelessWidget {
  const _Titles({required this.room, required this.myId});

  final MostLikelyRoom room;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final withTitles = [
      for (final player in room.players)
        if (room.titles[player.id]?.isNotEmpty ?? false) player,
    ];
    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('👑 Most likely to...', style: AppText.heading),
          if (withTitles.isEmpty)
            Text('Nobody won a title this time!', style: AppText.body),
          for (final player in withTitles) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlayerAvatar(index: player.avatarIndex, size: 40),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.id == myId ? 'You' : player.name,
                        style: AppText.label,
                      ),
                      for (final title in room.titles[player.id]!)
                        Text('• $title', style: AppText.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({
    required this.player,
    required this.rank,
    required this.points,
    required this.won,
    required this.isMe,
    required this.isAway,
  });

  final Player player;
  final int rank;
  final int points;

  /// Points from this round, if any.
  final int? won;
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
    final won = this.won;
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
                if (isAway) Text('Away', style: AppText.bodySmall),
              ],
            ),
          ),
          if (won != null && won > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('+$won', style: AppText.bodySmall),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text('$points', style: AppText.heading),
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

  final MostLikelyRoom room;
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
                  total: MostLikelyRoom.nextRoundWait,
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
                  child: Opacity(
                    opacity: ready.contains(player.id) ? 1 : 0.55,
                    child: PlayerAvatar(index: player.avatarIndex, size: 44),
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
