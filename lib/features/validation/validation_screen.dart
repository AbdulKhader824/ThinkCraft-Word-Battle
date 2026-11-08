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
import '../../core/widgets/mascot.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/answer_group.dart';
import '../../models/player.dart';
import '../../models/round.dart';
import '../../models/vote.dart';
import '../../services/game_providers.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';
import '../gameplay/category_picture.dart';
import '../gameplay/leave_game_guard.dart';

/// Shows anonymous answers one at a time. Only ballot items reach this
/// screen, and those carry no player identities at all.
class ValidationScreen extends ConsumerWidget {
  const ValidationScreen({super.key});

  /// How long a new answer ignores taps, to catch double taps.
  static const tapGuard = Duration(milliseconds: 350);

  static const _deal = Duration(milliseconds: 300);
  static const _countingKey = ValueKey('counting');

  static Key _keyFor(BallotItem? item) {
    return item == null ? _countingKey : ValueKey(item.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(gameRoomProvider);
    final round = room?.round;
    final letter = round?.letter;
    if (room == null || round == null || letter == null) {
      return const SizedBox.shrink();
    }
    final voteDeadline = round.voteDeadline;
    final voteTime = round.voteTime;
    final myId = ref.read(gameServiceProvider).localPlayerId;
    final stillVoting = [
      for (final player in room.players)
        if (player.id != myId &&
            !player.isBot &&
            !round.votedPlayerIds.contains(player.id))
          player,
    ];

    final item = round.nextBallotItem;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LeaveGameGuard(
      child: GameScreen(
        title: item == null ? 'Votes are in!' : 'Vote!',
        onBack: () => confirmLeaveGame(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (voteDeadline != null && voteTime != null) ...[
              _VoteTimer(
                deadline: voteDeadline,
                total: voteTime,
                finished: item == null,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _dealt(item, letter, round, stillVoting, reduceMotion),
          ],
        ),
      ),
    );
  }

  Widget _dealt(
    BallotItem? item,
    String letter,
    Round round,
    List<Player> stillVoting,
    bool reduceMotion,
  ) {
    // Answers are dealt like cards: the next one slides in from the
    // right as the last one slides away to the left.
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : _deal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == _keyFor(item);
        return SlideTransition(
          position: Tween(
            begin: Offset(incoming ? 1 : -1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: item == null
          ? _CountingVotes(key: _countingKey, stillVoting: stillVoting)
          : _BallotCard(
              key: _keyFor(item),
              item: item,
              letter: letter,
              round: round,
            ),
    );
  }
}

/// One timer for the whole ballot. Answers not voted on in time are
/// skipped, so nobody waits long for a slow phone.
class _VoteTimer extends StatelessWidget {
  const _VoteTimer({
    required this.deadline,
    required this.total,
    required this.finished,
  });

  final DateTime deadline;
  final Duration total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CountdownRing(deadline: deadline, total: total, size: 56),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            finished
                ? 'Voting ends when the time runs out.'
                : 'Answers left when time runs out are skipped.',
            style: AppText.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _BallotCard extends ConsumerStatefulWidget {
  const _BallotCard({
    super.key,
    required this.item,
    required this.letter,
    required this.round,
  });

  final BallotItem item;
  final String letter;
  final Round round;

  @override
  ConsumerState<_BallotCard> createState() => _BallotCardState();
}

class _BallotCardState extends ConsumerState<_BallotCard> {
  // Buttons sit in the same place on every card, so without this a double
  // tap would also vote on the next answer before anyone had read it.
  bool _acceptsVotes = false;
  late final Timer _guard;

  @override
  void initState() {
    super.initState();
    _guard = Timer(ValidationScreen.tapGuard, () => _acceptsVotes = true);
  }

  @override
  void dispose() {
    _guard.cancel();
    super.dispose();
  }

  void _vote(VoteChoice choice) {
    if (!_acceptsVotes) return;

    _acceptsVotes = false;
    playSound(ref, switch (choice) {
      VoteChoice.valid => GameSound.valid,
      VoteChoice.invalid => GameSound.invalid,
      VoteChoice.skip => GameSound.tap,
    });
    ref.read(gameServiceProvider).castVote(widget.item.id, choice);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final letter = widget.letter;
    final round = widget.round;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Answer ${round.myVotes.length + 1} of ${round.ballot.length}',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: AppSpacing.sm),
        GameCard(
          color: item.category.color,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The picture says the category at a glance.
              Center(
                child: CategoryPicture(category: item.category, height: 130),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.category.label,
                      textAlign: TextAlign.center,
                      style: AppText.heading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              GameCard(
                child: Text(
                  item.text,
                  textAlign: TextAlign.center,
                  style: AppText.title,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Is this a real ${item.category.label.toLowerCase()} '
                'starting with $letter?',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GameButton(
          label: 'Correct',
          icon: Icons.check_circle_rounded,
          style: GameButtonStyle.valid,
          sound: null,
          onPressed: () => _vote(VoteChoice.valid),
        ),
        const SizedBox(height: AppSpacing.sm),
        GameButton(
          label: 'Incorrect',
          icon: Icons.cancel_rounded,
          style: GameButtonStyle.invalid,
          sound: null,
          onPressed: () => _vote(VoteChoice.invalid),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: AppSizes.minTapTarget,
          child: TextButton(
            onPressed: () => _vote(VoteChoice.skip),
            child: Text(
              'Not sure? Skip this one',
              style: AppText.body.copyWith(color: AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountingVotes extends StatelessWidget {
  const _CountingVotes({super.key, required this.stillVoting});

  /// Players voting is still waiting for.
  final List<Player> stillVoting;

  String get _waitingText => switch (stillVoting) {
    [] => 'Almost done!',
    [final one] => 'Waiting for ${one.name}...',
    [final one, final two] => 'Waiting for ${one.name} and ${two.name}...',
    _ => 'Waiting for ${stillVoting.length} players...',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Mascot(size: 150)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Counting the votes...',
          textAlign: TextAlign.center,
          style: AppText.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(_waitingText, textAlign: TextAlign.center, style: AppText.body),
        if (stillVoting.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final player in stillVoting)
                Semantics(
                  label: '${player.name} is still voting',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerAvatar(index: player.avatarIndex, size: 44),
                      Text(player.name, style: AppText.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
