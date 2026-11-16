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
import '../../models/impostor_room.dart';
import '../../models/player.dart';
import '../../services/impostor/impostor_providers.dart';
import '../../services/rules/drawing_rules.dart';
import '../../services/rules/impostor_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';

/// What happened in the round and the leaderboard, with Next Round; after
/// the last round, the winner and the awards.
class ImpostorResultsScreen extends ConsumerStatefulWidget {
  const ImpostorResultsScreen({super.key});

  @override
  ConsumerState<ImpostorResultsScreen> createState() =>
      _ImpostorResultsScreenState();
}

class _ImpostorResultsScreenState extends ConsumerState<ImpostorResultsScreen> {
  bool _playedFanfare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playedFanfare) return;
    _playedFanfare = true;
    final room = ref.read(impostorRoomProvider);
    final myId = ref.read(impostorServiceProvider).localPlayerId;
    final won = room != null && room.isGameOver && _rankOf(room, myId) == 1;
    playSound(ref, won ? GameSound.win : GameSound.results);
  }

  static int? _rankOf(ImpostorRoom room, String? myId) {
    for (final entry in _ranked(room)) {
      if (entry.playerId == myId) return entry.rank;
    }
    return null;
  }

  static List<({String playerId, int rank, int points})> _ranked(
    ImpostorRoom room,
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
    final room = ref.watch(impostorRoomProvider);
    final service = ref.watch(impostorServiceProvider);
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
                      if (room.isGameOver) ...[
                        Entrance(
                          child: _WinnerBanner(room: room, ranked: ranked),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Entrance(index: 1, child: _Awards(room: room)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Entrance(
                        index: 1,
                        child: _RoundSummary(room: room, myId: myId),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        room.isGameOver ? 'Final scores' : 'Scores',
                        style: AppText.heading,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final (index, entry) in ranked.indexed) ...[
                        Entrance(
                          index: index + 2,
                          child: _PlayerLine(
                            player: room.playerOrNull(entry.playerId)!,
                            rank: entry.rank,
                            points: entry.points,
                            won: room.roundPoints[entry.playerId],
                            isMe: entry.playerId == myId,
                            isAway: room.awayIds.contains(entry.playerId),
                            wasImpostor: entry.playerId == room.impostorId,
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

/// The word, the Impostor, whether they were caught and their guess.
class _RoundSummary extends StatelessWidget {
  const _RoundSummary({required this.room, required this.myId});

  final ImpostorRoom room;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final impostor = room.impostor;
    final name = impostor == null
        ? 'The Impostor'
        : impostor.id == myId
        ? 'You'
        : impostor.name;
    final word = (room.word ?? '').toUpperCase();

    if (room.roundEnd == RoundEnd.impostorLeft) {
      return GameCard(
        color: AppColors.sunshine,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(
              'The Impostor left!',
              textAlign: TextAlign.center,
              style: AppText.title,
            ),
            Text(
              'Nobody scores this round. The word was $word.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      );
    }

    final caught = room.caught ?? false;
    final guessed = room.guessedWord;
    final String guessLine;
    if (room.guessedRight) {
      guessLine =
          '😮 $name guessed it: $word! +${ImpostorRules.rightGuessPoints}';
    } else if (guessed == null) {
      guessLine = "⏰ $name didn't guess in time.";
    } else {
      guessLine = '❌ $name guessed ${guessed.toUpperCase()}. Wrong!';
    }

    return GameCard(
      color: caught ? AppColors.mint : AppColors.coral,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (impostor != null)
                PlayerAvatar(index: impostor.avatarIndex, size: 64),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caught ? '🎉 Caught!' : '😈 Not caught!',
                      style: AppText.title,
                    ),
                    Text(
                      name == 'You'
                          ? 'You were the Impostor'
                          : '$name was the Impostor',
                      style: AppText.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('The word was', style: AppText.bodySmall),
          Text(word, key: const ValueKey('results-word'), style: AppText.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(guessLine, style: AppText.label),
          if (room.votes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final player in room.players)
                  if (room.votes[player.id] case final suspect?)
                    Text(
                      '${player.name} → '
                      '${room.playerOrNull(suspect)?.name ?? '?'}',
                      style: AppText.bodySmall,
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.room, required this.ranked});

  final ImpostorRoom room;
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
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: Colors.white),
          ),
          Text(
            'Final results after ${room.settings.rounds} rounds',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Best Detective and Master of Disguise.
class _Awards extends StatelessWidget {
  const _Awards({required this.room});

  final ImpostorRoom room;

  String _names(List<String> ids) =>
      [for (final id in ids) room.playerOrNull(id)?.name ?? '']
          .where((name) => name.isNotEmpty)
          .join(' & ');

  @override
  Widget build(BuildContext context) {
    final scores = {
      for (final player in room.players) player.id: room.scoreOf(player.id),
    };
    final detectives = ImpostorRules.bestDetectives(scores);
    final disguises = ImpostorRules.mastersOfDisguise(scores);
    if (detectives.isEmpty && disguises.isEmpty) return const SizedBox.shrink();

    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detectives.isNotEmpty)
            _Award(
              emoji: '⭐',
              title: 'Best Detective',
              names: _names(detectives),
              detail: '${scores[detectives.first]!.rightVotes} right votes',
            ),
          if (detectives.isNotEmpty && disguises.isNotEmpty)
            const SizedBox(height: AppSpacing.xs),
          if (disguises.isNotEmpty)
            _Award(
              emoji: '🎭',
              title: 'Master of Disguise',
              names: _names(disguises),
              detail:
                  '${scores[disguises.first]!.impostorPoints} points as the '
                  'Impostor',
            ),
        ],
      ),
    );
  }
}

class _Award extends StatelessWidget {
  const _Award({
    required this.emoji,
    required this.title,
    required this.names,
    required this.detail,
  });

  final String emoji;
  final String title;
  final String names;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: AppText.title),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.label),
              Text(names, style: AppText.heading),
              Text(detail, style: AppText.bodySmall),
            ],
          ),
        ),
      ],
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
    required this.wasImpostor,
  });

  final Player player;
  final int rank;
  final int points;

  /// Points from this round, if any.
  final int? won;
  final bool isMe;
  final bool isAway;
  final bool wasImpostor;

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
                  '${isMe ? '${player.name} (you)' : player.name}'
                  '${wasImpostor ? ' 🕵️' : ''}',
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

  final ImpostorRoom room;
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
                  total: ImpostorRoom.nextRoundWait,
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
