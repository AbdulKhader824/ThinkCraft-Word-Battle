import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/mascot.dart';
import '../../models/answer_group.dart';
import '../../models/round.dart';
import '../../models/vote.dart';
import '../../services/game_providers.dart';
import '../gameplay/category_style.dart';
import '../gameplay/leave_game_guard.dart';

/// Shows anonymous answers one at a time. Only ballot items reach this
/// screen, and those carry no player identities at all.
class ValidationScreen extends ConsumerWidget {
  const ValidationScreen({super.key});

  /// How long a new answer ignores taps, to catch double taps.
  static const tapGuard = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(gameRoomProvider)?.round;
    final letter = round?.letter;
    if (round == null || letter == null) return const SizedBox.shrink();

    final item = round.nextBallotItem;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LeaveGameGuard(
      child: GameScreen(
        title: 'Vote!',
        onBack: () => confirmLeaveGame(context, ref),
        child: AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : AppDurations.medium,
          child: item == null
              ? const _CountingVotes()
              : _BallotCard(
                  key: ValueKey(item.id),
                  item: item,
                  letter: letter,
                  round: round,
                ),
        ),
      ),
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
              Row(
                children: [
                  SvgPicture.asset(
                    item.category.character,
                    width: 56,
                    height: 56,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(item.category.label, style: AppText.heading),
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
          label: 'Valid',
          icon: Icons.check_circle_rounded,
          style: GameButtonStyle.valid,
          onPressed: () => _vote(VoteChoice.valid),
        ),
        const SizedBox(height: AppSpacing.sm),
        GameButton(
          label: 'Invalid',
          icon: Icons.cancel_rounded,
          style: GameButtonStyle.invalid,
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
  const _CountingVotes();

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
        Text(
          'Waiting for the other players.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      ],
    );
  }
}
