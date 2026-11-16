import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/impostor_room.dart';
import '../../models/player.dart';
import '../../services/impostor/impostor_providers.dart';
import '../../services/impostor/impostor_service.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';

/// One round of The Impostor, from the secret word to the Impostor's
/// guess. Each stage swaps the middle of the screen.
class ImpostorPlayScreen extends ConsumerWidget {
  const ImpostorPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(impostorRoomProvider);
    final service = ref.watch(impostorServiceProvider);
    final myId = service.localPlayerId;
    ref.listen(impostorRoomProvider, (previous, next) {
      _playSounds(ref, previous, next, myId);
    });
    if (room == null || myId == null) return const SizedBox.shrink();

    final body = switch (room.phase) {
      ImpostorPhase.word => _WordStage(room: room),
      ImpostorPhase.clues => _ClueStage(
        room: room,
        myId: myId,
        service: service,
      ),
      ImpostorPhase.talk => _TalkStage(
        room: room,
        myId: myId,
        service: service,
      ),
      ImpostorPhase.vote => _VoteStage(
        key: ValueKey('vote-${room.round}'),
        room: room,
        myId: myId,
        service: service,
      ),
      ImpostorPhase.reveal => _RevealStage(
        key: ValueKey('reveal-${room.round}'),
        room: room,
      ),
      ImpostorPhase.guess => _GuessStage(
        key: ValueKey('guess-${room.round}'),
        room: room,
        myId: myId,
        service: service,
      ),
      ImpostorPhase.lobby || ImpostorPhase.results => const SizedBox.shrink(),
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
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  static void _playSounds(
    WidgetRef ref,
    ImpostorRoom? previous,
    ImpostorRoom? next,
    String? myId,
  ) {
    if (previous == null || next == null) return;
    final newStage =
        next.phase != previous.phase || next.clueIndex != previous.clueIndex;
    if (!newStage) {
      if (next.votedIds.length > previous.votedIds.length &&
          next.phase == ImpostorPhase.vote) {
        playSound(ref, GameSound.tick);
      }
      return;
    }
    switch (next.phase) {
      case ImpostorPhase.word:
        playSound(ref, GameSound.select);
      case ImpostorPhase.clues when next.speakerId == myId:
        playSound(ref, GameSound.ready);
      case ImpostorPhase.vote:
        playSound(ref, GameSound.lock);
      case ImpostorPhase.reveal:
        playSound(ref, GameSound.reveal);
      default:
        break;
    }
  }
}

/// The stage, the round and topic, and the timer.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.room, required this.onLeave});

  final ImpostorRoom room;
  final VoidCallback onLeave;

  String get _stage => switch (room.phase) {
    ImpostorPhase.word => 'Secret word',
    ImpostorPhase.clues => 'Clues',
    ImpostorPhase.talk => 'Talk it over',
    ImpostorPhase.vote => 'Vote',
    ImpostorPhase.reveal => 'The reveal',
    ImpostorPhase.guess => 'Last chance',
    _ => '',
  };

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
                _stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label,
              ),
              Text(
                'Round ${room.round} of ${room.settings.rounds}'
                '${topic == null ? '' : ' · ${topic.emoji} ${topic.label}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall,
              ),
            ],
          ),
        ),
        if (deadline != null)
          CountdownRing(
            key: ValueKey(
              'ring-${room.round}-${room.phase.name}-${room.clueIndex}',
            ),
            deadline: deadline,
            total: room.stageTime,
            size: 56,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- the word

/// The secret, shown only while held down, so nobody can peek.
class _SecretCard extends StatefulWidget {
  const _SecretCard({required this.room, this.compact = false});

  final ImpostorRoom room;

  /// A smaller card, for checking the word again later in the round.
  final bool compact;

  @override
  State<_SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<_SecretCard> {
  bool _showing = false;

  void _show(bool showing) {
    if (showing == _showing) return;
    setState(() => _showing = showing);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final compact = widget.compact;
    final topic = room.topic;
    final Widget face;
    if (!_showing) {
      face = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_rounded,
            color: AppColors.sunshine,
            size: compact ? 32 : 64,
          ),
          Text(
            compact ? 'Hold to see your word again' : 'Hold to see your word',
            textAlign: TextAlign.center,
            style: (compact ? AppText.label : AppText.heading).copyWith(
              color: Colors.white,
            ),
          ),
          if (!compact)
            Text(
              'Let go to hide it. No peeking!',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: Colors.white),
            ),
        ],
      );
    } else if (room.isImpostor) {
      face = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🕵️', style: compact ? AppText.title : AppText.display),
          Text(
            'You are the Impostor!',
            key: const ValueKey('impostor-secret'),
            textAlign: TextAlign.center,
            style: (compact ? AppText.heading : AppText.title).copyWith(
              color: AppColors.coral,
            ),
          ),
          if (topic != null)
            Text(
              'Topic: ${topic.label}',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: Colors.white),
            ),
          if (!compact)
            Text(
              'Listen carefully and blend in.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: Colors.white),
            ),
        ],
      );
    } else {
      face = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topic != null)
            Text(
              '${topic.emoji} ${topic.label}',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: Colors.white),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              (room.word ?? '').toUpperCase(),
              key: const ValueKey('secret-word'),
              maxLines: 1,
              style: (compact ? AppText.title : AppText.display).copyWith(
                color: AppColors.sunshine,
                letterSpacing: 2,
              ),
            ),
          ),
          if (!compact)
            Text(
              "Give clues, but don't say it!",
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: Colors.white),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: _showing
          ? (room.isImpostor
                ? 'You are the Impostor. Topic ${topic?.label ?? ''}'
                : 'Your word is ${room.word}')
          : 'Hold to see your word',
      excludeSemantics: true,
      onTap: () => _show(!_showing),
      child: Listener(
        key: const ValueKey('secret-card'),
        onPointerDown: (_) => _show(true),
        onPointerUp: (_) => _show(false),
        onPointerCancel: (_) => _show(false),
        child: GameCard(
          color: AppColors.navy,
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: compact ? AppSizes.mainButton : 220,
            ),
            child: Center(child: face),
          ),
        ),
      ),
    );
  }
}

class _WordStage extends StatelessWidget {
  const _WordStage({required this.room});

  final ImpostorRoom room;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SecretCard(room: room),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Everyone gets the same word, except the Impostor.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- the clues

class _ClueStage extends StatelessWidget {
  const _ClueStage({
    required this.room,
    required this.myId,
    required this.service,
  });

  final ImpostorRoom room;
  final String myId;
  final ImpostorService service;

  @override
  Widget build(BuildContext context) {
    final speaker = room.playerOrNull(room.speakerId);
    final myTurn = room.speakerId == myId;
    final turnsEach = room.settings.clueTurns;
    final perLap = room.clueOrder.length ~/ turnsEach;
    final lap = perLap == 0 ? 1 : room.clueIndex ~/ perLap + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecretCard(room: room, compact: true),
        const SizedBox(height: AppSpacing.sm),
        _ClueOrder(room: room),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (speaker != null)
                    PlayerAvatar(index: speaker.avatarIndex, size: 112),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    myTurn
                        ? 'Your turn! Say a clue out loud.'
                        : "${speaker?.name ?? 'Someone'}'s turn",
                    textAlign: TextAlign.center,
                    style: AppText.title,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    "Give a clue, don't say the word!",
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  if (turnsEach > 1)
                    Text(
                      'Clue turn $lap of $turnsEach',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (myTurn)
          GameButton(
            label: 'Done',
            icon: Icons.check_circle_rounded,
            onPressed: service.clueDone,
          ),
      ],
    );
  }
}

/// Everyone's faces in clue order, with the speaker picked out and those
/// who've spoken faded.
class _ClueOrder extends StatelessWidget {
  const _ClueOrder({required this.room});

  final ImpostorRoom room;

  @override
  Widget build(BuildContext context) {
    final perLap = room.clueOrder.length ~/ room.settings.clueTurns;
    final lapStart = perLap == 0 ? 0 : (room.clueIndex ~/ perLap) * perLap;
    final lap = room.clueOrder.skip(lapStart).take(perLap).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (offset, id) in lap.indexed)
            _OrderFace(
              player: room.playerOrNull(id),
              current: lapStart + offset == room.clueIndex,
              done: lapStart + offset < room.clueIndex,
              away: room.awayIds.contains(id),
            ),
        ],
      ),
    );
  }
}

class _OrderFace extends StatelessWidget {
  const _OrderFace({
    required this.player,
    required this.current,
    required this.done,
    required this.away,
  });

  final Player? player;
  final bool current;
  final bool done;
  final bool away;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (player == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        label:
            '${player.name}${current
                ? ', speaking now'
                : done
                ? ', done'
                : ''}',
        excludeSemantics: true,
        child: Opacity(
          opacity: done || away ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current ? AppColors.sunshine : Colors.transparent,
            ),
            child: PlayerAvatar(index: player.avatarIndex, size: 40),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ talk it over

class _TalkStage extends StatelessWidget {
  const _TalkStage({
    required this.room,
    required this.myId,
    required this.service,
  });

  final ImpostorRoom room;
  final String myId;
  final ImpostorService service;

  @override
  Widget build(BuildContext context) {
    final isHost = room.host.id == myId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecretCard(room: room, compact: true),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text('🗣️', style: AppText.display),
                  Text(
                    "Who's the Impostor?",
                    textAlign: TextAlign.center,
                    style: AppText.title,
                  ),
                  Text(
                    'Talk about it! Whose clue sounded odd?',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isHost
                        ? 'Tap Vote now when everyone is ready.'
                        : 'The vote starts when time is up, or when the '
                              'host taps Vote now.',
                    textAlign: TextAlign.center,
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isHost)
          GameButton(
            label: 'Vote now',
            icon: Icons.how_to_vote_rounded,
            onPressed: service.voteNow,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- voting

class _VoteStage extends StatefulWidget {
  const _VoteStage({
    super.key,
    required this.room,
    required this.myId,
    required this.service,
  });

  final ImpostorRoom room;
  final String myId;
  final ImpostorService service;

  @override
  State<_VoteStage> createState() => _VoteStageState();
}

class _VoteStageState extends State<_VoteStage> {
  String? _picked;

  /// Shown at once, before the host confirms it.
  String? _sent;

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
          locked == null ? 'Who is the Impostor?' : 'Vote locked!',
          textAlign: TextAlign.center,
          style: AppText.title,
        ),
        Text(
          locked == null
              ? 'Tap a face, then Lock vote. Votes are secret.'
              : 'You voted for ${room.playerOrNull(locked)?.name ?? 'someone'}. '
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
                    onTap: locked != null || player.id == widget.myId
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
                    final suspect = _picked!;
                    setState(() => _sent = suspect);
                    widget.service.vote(suspect);
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
        opacity: isMe || away ? 0.5 : 1,
        child: Material(
          color: selected ? AppColors.coral : AppColors.cream,
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

/// The votes turn over one by one, then who the Impostor was.
class _RevealStage extends StatefulWidget {
  const _RevealStage({super.key, required this.room});

  final ImpostorRoom room;

  @override
  State<_RevealStage> createState() => _RevealStageState();
}

class _RevealStageState extends State<_RevealStage> {
  static const _step = Duration(milliseconds: 700);

  Timer? _timer;
  int _shown = 0;

  int get _total => widget.room.votes.length + 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _shown > 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = _total;
      return;
    }
    _timer = Timer.periodic(_step, (timer) {
      if (!mounted) return;
      setState(() => _shown++);
      if (_shown >= _total) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final votes = [
      for (final player in room.players)
        if (room.votes[player.id] != null) (player, room.votes[player.id]!),
    ];
    final allShown = _shown >= votes.length + 1;
    final impostor = room.impostor;
    final caught = room.caught ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🥁 The votes',
            textAlign: TextAlign.center,
            style: AppText.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (votes.isEmpty)
            Text(
              'Nobody voted!',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          for (final (index, (voter, suspectId)) in votes.indexed)
            AnimatedOpacity(
              opacity: index < _shown ? 1 : 0,
              duration: AppDurations.medium,
              child: _VoteLine(
                voter: voter,
                suspect: room.playerOrNull(suspectId),
                right: suspectId == room.impostorId,
                shown: index < _shown,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (allShown && impostor != null)
            GameCard(
              color: caught ? AppColors.mint : AppColors.coral,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  PlayerAvatar(index: impostor.avatarIndex, size: 96),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    caught ? '🎉 Caught!' : '😈 Not caught!',
                    key: const ValueKey('reveal-result'),
                    textAlign: TextAlign.center,
                    style: AppText.title,
                  ),
                  Text(
                    '${impostor.name} was the Impostor!',
                    textAlign: TextAlign.center,
                    style: AppText.heading,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Now ${impostor.name} gets one guess at the word.',
                    textAlign: TextAlign.center,
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VoteLine extends StatelessWidget {
  const _VoteLine({
    required this.voter,
    required this.suspect,
    required this.right,
    required this.shown,
  });

  final Player voter;
  final Player? suspect;
  final bool right;
  final bool shown;

  @override
  Widget build(BuildContext context) {
    final suspect = this.suspect;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GameCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          children: [
            PlayerAvatar(index: voter.avatarIndex, size: 36),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                voter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.navy),
            const SizedBox(width: AppSpacing.xs),
            if (suspect != null) ...[
              PlayerAvatar(index: suspect.avatarIndex, size: 36),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  suspect.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- guess

class _GuessStage extends StatefulWidget {
  const _GuessStage({
    super.key,
    required this.room,
    required this.myId,
    required this.service,
  });

  final ImpostorRoom room;
  final String myId;
  final ImpostorService service;

  @override
  State<_GuessStage> createState() => _GuessStageState();
}

class _GuessStageState extends State<_GuessStage> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final impostor = room.impostor;
    final isImpostor = room.isImpostor;
    final name = impostor?.name ?? 'The Impostor';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (impostor != null)
            Center(child: PlayerAvatar(index: impostor.avatarIndex, size: 88)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isImpostor ? 'Guess the word!' : '$name is guessing the word...',
            textAlign: TextAlign.center,
            style: AppText.title,
          ),
          Text(
            isImpostor
                ? (room.caught ?? false)
                      ? 'You were caught, but a right guess still wins '
                            'points!'
                      : 'You got away! Guess right for even more points.'
                : 'Can they work it out from your clues?',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - AppSpacing.xs) / 2;
              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (index, word) in room.guessChoices.indexed)
                    SizedBox(
                      width: width,
                      child: _GuessTile(
                        key: ValueKey('guess-$index'),
                        word: word,
                        color: AppColors.candy[index % AppColors.candy.length],
                        picked: _picked == word,
                        onTap: isImpostor && _picked == null
                            ? () {
                                playSoundFrom(context, GameSound.lock);
                                setState(() => _picked = word);
                                widget.service.guessWord(word);
                              }
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuessTile extends StatelessWidget {
  const _GuessTile({
    super.key,
    required this.word,
    required this.color,
    required this.picked,
    required this.onTap,
  });

  final String word;
  final Color color;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    return Semantics(
      button: onTap != null,
      selected: picked,
      label: word,
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.mainButton),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.navy, width: picked ? 5 : 2),
            ),
            child: Text(
              word.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.label,
            ),
          ),
        ),
      ),
    );
  }
}
