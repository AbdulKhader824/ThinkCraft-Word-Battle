import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/most_likely_room.dart';
import '../../models/player.dart';
import '../../services/most_likely/most_likely_providers.dart';
import '../../services/most_likely/most_likely_service.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';

/// One question of Most Likely To...: the secret vote, then the reveal.
class MostLikelyPlayScreen extends ConsumerWidget {
  const MostLikelyPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(mostLikelyRoomProvider);
    final service = ref.watch(mostLikelyServiceProvider);
    final myId = service.localPlayerId;
    ref.listen(mostLikelyRoomProvider, (previous, next) {
      _playSounds(ref, previous, next);
    });
    if (room == null || myId == null) return const SizedBox.shrink();

    final body = switch (room.phase) {
      MostLikelyPhase.vote => _VoteStage(
        key: ValueKey('vote-${room.questionNumber}'),
        room: room,
        myId: myId,
        service: service,
      ),
      MostLikelyPhase.reveal => _RevealStage(
        key: ValueKey('reveal-${room.questionNumber}'),
        room: room,
        myId: myId,
      ),
      MostLikelyPhase.lobby ||
      MostLikelyPhase.results => const SizedBox.shrink(),
    };

    return LeaveGameGuard(
      leave: service.leaveRoom,
      child: GameFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                room: room,
                onLeave: () =>
                    confirmLeaveGame(context, ref, leave: service.leaveRoom),
              ),
              const SizedBox(height: AppSpacing.sm),
              _QuestionCard(room: room),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  static void _playSounds(
    WidgetRef ref,
    MostLikelyRoom? previous,
    MostLikelyRoom? next,
  ) {
    if (previous == null || next == null) return;
    final newStage =
        next.phase != previous.phase ||
        next.questionNumber != previous.questionNumber;
    if (!newStage) {
      if (next.votedIds.length > previous.votedIds.length &&
          next.phase == MostLikelyPhase.vote) {
        playSound(ref, GameSound.tick);
      }
      return;
    }
    switch (next.phase) {
      case MostLikelyPhase.vote:
        playSound(ref, GameSound.select);
      case MostLikelyPhase.reveal:
        playSound(ref, GameSound.reveal);
      default:
        break;
    }
  }
}

/// The question number, the topic and the timer.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.room, required this.onLeave});

  final MostLikelyRoom room;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final deadline = room.deadline;
    final topic = room.topic;
    return Row(
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(
            tooltip: 'Leave game',
            iconSize: 26,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget,
            ),
            color: AppColors.navy,
            onPressed: onLeave,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${room.questionNumber} of '
                '${room.settings.questions}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label,
              ),
              if (topic != null)
                Text(
                  '${topic.emoji} ${topic.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySmall,
                ),
            ],
          ),
        ),
        if (deadline != null)
          CountdownRing(
            key: ValueKey('ring-${room.questionNumber}-${room.phase.name}'),
            deadline: deadline,
            total: room.stageTime,
            size: 56,
          ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.room});

  final MostLikelyRoom room;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            'Who is most likely to...',
            textAlign: TextAlign.center,
            style: AppText.label,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${room.question ?? ''}?',
            key: const ValueKey('question'),
            textAlign: TextAlign.center,
            style: AppText.title,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ vote

class _VoteStage extends StatefulWidget {
  const _VoteStage({
    super.key,
    required this.room,
    required this.myId,
    required this.service,
  });

  final MostLikelyRoom room;
  final String myId;
  final MostLikelyService service;

  @override
  State<_VoteStage> createState() => _VoteStageState();
}

class _VoteStageState extends State<_VoteStage> {
  String? _picked;

  /// Shown at once, before the host confirms it.
  String? _sent;

  String _nameOf(String id) => id == widget.myId
      ? 'yourself'
      : widget.room.playerOrNull(id)?.name ?? 'someone';

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final locked = room.votes[widget.myId] ?? _sent;
    final waiting = room.players
        .where(
          (p) => !room.votedIds.contains(p.id) && !room.awayIds.contains(p.id),
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          locked == null
              ? 'Tap a face, then Lock vote. You can pick yourself!'
              : 'You voted for ${_nameOf(locked)}. '
                    '${waiting == 0 ? '' : 'Waiting for $waiting more...'}',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final player in room.players)
                  _VoteFace(
                    key: ValueKey('vote-${player.id}'),
                    player: player,
                    isMe: player.id == widget.myId,
                    selected: (locked ?? _picked) == player.id,
                    voted: room.votedIds.contains(player.id),
                    away: room.awayIds.contains(player.id),
                    onTap: locked != null
                        ? null
                        : () {
                            playSoundFrom(context, GameSound.select);
                            setState(() => _picked = player.id);
                          },
                  ),
              ],
            ),
          ),
        ),
        if (locked == null)
          GameButton(
            label: 'Lock vote',
            icon: Icons.lock_rounded,
            sound: GameSound.lock,
            onPressed: _picked == null
                ? null
                : () {
                    final choice = _picked!;
                    setState(() => _sent = choice);
                    widget.service.vote(choice);
                  },
          ),
      ],
    );
  }
}

class _VoteFace extends StatelessWidget {
  const _VoteFace({
    super.key,
    required this.player,
    required this.isMe,
    required this.selected,
    required this.voted,
    required this.away,
    required this.onTap,
  });

  final Player player;
  final bool isMe;
  final bool selected;
  final bool voted;
  final bool away;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${isMe ? 'You' : player.name}${voted ? ', has voted' : ''}'
          '${away ? ', away' : ''}',
      excludeSemantics: true,
      child: Opacity(
        opacity: away ? 0.5 : 1,
        child: Material(
          color: selected ? AppColors.mint : AppColors.cream,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? AppColors.navy : AppColors.outline,
                  width: selected ? 3 : 2,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PlayerAvatar(index: player.avatarIndex, size: 56),
                      if (voted)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.valid,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    isMe ? 'You' : player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- reveal

/// How many votes each player got, never who gave them, with a crown on
/// the most likely, and whether this player read the room.
class _RevealStage extends StatelessWidget {
  const _RevealStage({super.key, required this.room, required this.myId});

  final MostLikelyRoom room;
  final String myId;

  String get _headline {
    final names = [
      for (final player in room.players)
        if (room.mostLikelyIds.contains(player.id))
          player.id == myId ? 'You' : player.name,
    ];
    if (names.isEmpty) return 'Nobody voted!';
    if (names.length == 1) {
      return names.single == 'You'
          ? "It's you! 🎉"
          : '${names.single} is most likely! 🎉';
    }
    final last = names.removeLast();
    return "It's a tie: ${names.join(', ')} and $last! 🎉";
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final most = room.voteCounts.values.fold(0, (a, b) => a > b ? a : b);
    final players = [...room.players]
      ..sort(
        (a, b) =>
            (room.voteCounts[b.id] ?? 0).compareTo(room.voteCounts[a.id] ?? 0),
      );
    final voted = room.votes.containsKey(myId);
    final point = room.questionPoints[myId] ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _headline,
            key: const ValueKey('reveal-headline'),
            textAlign: TextAlign.center,
            style: AppText.title,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final player in players) ...[
            _VoteBar(
              player: player,
              isMe: player.id == myId,
              votes: room.voteCounts[player.id] ?? 0,
              most: most,
              crowned: room.mostLikelyIds.contains(player.id),
              animate: !reduceMotion,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.xs),
          GameCard(
            color: point > 0 ? AppColors.mint : AppColors.lavender,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              !voted
                  ? "You didn't vote this time."
                  : point > 0
                  ? '🧠 You read the room! +$point'
                  : 'Not this time. Keep reading the room!',
              key: const ValueKey('reveal-points'),
              textAlign: TextAlign.center,
              style: AppText.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({
    required this.player,
    required this.isMe,
    required this.votes,
    required this.most,
    required this.crowned,
    required this.animate,
  });

  final Player player;
  final bool isMe;
  final int votes;
  final int most;
  final bool crowned;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final share = most == 0 ? 0.0 : votes / most;
    final name = isMe ? 'You' : player.name;
    return Semantics(
      label:
          '$name, $votes ${votes == 1 ? 'vote' : 'votes'}'
          '${crowned ? ', most likely' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(index: player.avatarIndex, size: 48),
                if (crowned)
                  Positioned(
                    top: -14,
                    left: 10,
                    child: SvgPicture.asset(AppAssets.crown, width: 30),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
                const SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Container(
                    height: 14,
                    color: AppColors.cream,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: animate ? 0 : share, end: share),
                      duration: AppDurations.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          color: crowned ? AppColors.mint : AppColors.sky,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$votes', style: AppText.heading),
        ],
      ),
    );
  }
}
