import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/answer_group.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../models/round_results.dart';
import '../../services/game_providers.dart';
import '../../services/rules/scoring_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';
import '../gameplay/leave_game_guard.dart';

/// The leaderboard. One [AnimationController] runs the whole entrance: the
/// trophy pops in, then each player slides in a little after the one above,
/// while the totals count up from their old values.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  static const entrance = Duration(milliseconds: 1400);

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ResultsScreen.entrance,
  );

  bool _playedFanfare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_playedFanfare) {
      _playedFanfare = true;
      playSound(ref, _isWinner() ? GameSound.win : GameSound.results);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (_entrance.value == 0 && !_entrance.isAnimating) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// True when this player has won the whole game.
  bool _isWinner() {
    final room = ref.read(gameRoomProvider);
    final myId = ref.read(gameServiceProvider).localPlayerId;
    if (room == null || myId == null || !room.isFinalRound) return false;
    final ranked = ScoringRules.rank(room.scores, room.playerIds);
    return ranked.firstWhere((entry) => entry.playerId == myId).rank == 1;
  }

  /// Each card starts a little after the one above it.
  Animation<double> _cardAnimation(int index) {
    final start = (0.2 + index * 0.07).clamp(0.0, 0.7);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, start + 0.3, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(gameRoomProvider);
    final results = room?.round?.results;
    final service = ref.read(gameServiceProvider);
    if (room == null || results == null) return const SizedBox.shrink();

    final ranked = ScoringRules.rank(room.scores, room.playerIds);
    final myRank = ranked
        .firstWhere((entry) => entry.playerId == service.localPlayerId)
        .rank;
    final counting = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    );

    return LeaveGameGuard(
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
                      _WinnerBanner(
                        room: room,
                        ranked: ranked,
                        pop: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0,
                            0.45,
                            curve: Curves.elasticOut,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tap a player to see their answers.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final (index, entry) in ranked.indexed) ...[
                        _SlideIn(
                          animation: _cardAnimation(index),
                          child: _PlayerResultCard(
                            player: room.playerById(entry.playerId),
                            rank: entry.rank,
                            gameScore: entry.score,
                            roundScore: results.scores[entry.playerId]!,
                            lines: results.lines[entry.playerId]!,
                            isMe: entry.playerId == service.localPlayerId,
                            counting: counting,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                  child: _ResultActions(
                    // After the final round, a new game replaces the next round.
                    nextLabel: room.isFinalRound ? 'New Game' : 'Next Round',
                    onNext: room.isFinalRound
                        ? service.newGame
                        : service.nextRound,
                    onReturnHome: service.leaveRoom,
                  ),
                ),
              ],
            ),
            // Saved for winning the whole game, so it stays special.
            if (room.isFinalRound && myRank == 1)
              const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }
}

/// Next Round (or New Game) and Return Home. Side by side when there's room;
/// stacked and smaller on narrow phones or with large text, so they never
/// crowd out the leaderboard.
class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.nextLabel,
    required this.onNext,
    required this.onReturnHome,
  });

  /// Below this width per button, the labels would wrap onto several lines.
  static const _minSideBySideWidth = 160.0;
  static const _maxSideBySideTextScale = 1.2;

  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - AppSpacing.xs) / 2;
        final stacked =
            halfWidth < _minSideBySideWidth ||
            textScale > _maxSideBySideTextScale;

        final next = GameButton(
          label: nextLabel,
          compact: stacked,
          onPressed: onNext,
        );
        final returnHome = GameButton(
          label: 'Return Home',
          style: GameButtonStyle.sky,
          compact: stacked,
          onPressed: onReturnHome,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              next,
              const SizedBox(height: AppSpacing.xxs),
              returnHome,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: next),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: returnHome),
          ],
        );
      },
    );
  }
}

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({
    required this.room,
    required this.ranked,
    required this.pop,
  });

  final Room room;
  final List<LeaderboardEntry> ranked;
  final Animation<double> pop;

  String get _headline {
    final leaders = ranked.where((entry) => entry.rank == 1).toList();
    if (leaders.length > 1) return "It's a tie!";

    final name = room.playerById(leaders.single.playerId).name;
    return room.isFinalRound ? '$name wins!' : '$name is leading!';
  }

  String get _subtitle {
    if (!room.isFinalRound) return '${roundLabel(room)} results';
    final rounds = room.settings.rounds;
    return rounds == 1 ? 'Final results' : 'Final results after $rounds rounds';
  }

  @override
  Widget build(BuildContext context) {
    final onNavy = AppText.body.copyWith(color: Colors.white);

    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          ScaleTransition(
            scale: pop,
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.sunshine,
              size: 56,
            ),
          ),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: Colors.white),
          ),
          Text(_subtitle, textAlign: TextAlign.center, style: onNavy),
        ],
      ),
    );
  }
}

class _PlayerResultCard extends StatelessWidget {
  const _PlayerResultCard({
    required this.player,
    required this.rank,
    required this.gameScore,
    required this.roundScore,
    required this.lines,
    required this.isMe,
    required this.counting,
  });

  /// Answers worth the full 10 points were unique, which earns a star.
  static const _uniqueAnswerPoints = 1000;

  final Player player;
  final int rank;
  final ScoreLine gameScore;
  final ScoreLine roundScore;
  final List<AnswerLine> lines;
  final bool isMe;
  final Animation<double> counting;

  @override
  Widget build(BuildContext context) {
    final stars = lines
        .where((line) => line.points == _uniqueAnswerPoints)
        .length;
    final previousTotal = gameScore.total - roundScore.total;

    return GameCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey(player.id),
            iconColor: AppColors.navy,
            collapsedIconColor: AppColors.navy,
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            title: Row(
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: AppSpacing.xs),
                PlayerAvatar(index: player.avatarIndex, size: 48),
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
                      if (stars > 0) _Stars(count: stars),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedBuilder(
                  animation: counting,
                  builder: (context, _) {
                    final shown =
                        previousTotal +
                        (roundScore.total * counting.value).round();
                    // Big totals shrink to fit rather than squeeze the name.
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 76),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          ScoringRules.formatPoints(shown),
                          style: AppText.heading,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            children: [
              _ScoreSummary(roundScore: roundScore, gameScore: gameScore),
              const SizedBox(height: AppSpacing.xs),
              for (final line in lines) _AnswerRow(line: line),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  Color? get _trophy => switch (rank) {
    1 => AppColors.gold,
    2 => AppColors.silver,
    3 => AppColors.bronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final trophy = _trophy;

    return SizedBox(
      width: 34,
      child: Column(
        children: [
          if (trophy != null)
            Icon(Icons.emoji_events_rounded, color: trophy, size: 24),
          Text('#$rank', style: AppText.bodySmall),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count unique answers',
      excludeSemantics: true,
      child: Wrap(
        children: [
          for (var star = 0; star < count; star++)
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
        ],
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.roundScore, required this.gameScore});

  final ScoreLine roundScore;
  final ScoreLine gameScore;

  String get _validation {
    final points = roundScore.validationPoints;
    return points > 0 ? '+$points' : '$points';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _ScoreChip(
          label: 'Answers',
          value: ScoringRules.formatPoints(roundScore.answerPoints),
        ),
        _ScoreChip(label: 'Validation', value: _validation),
        _ScoreChip(
          label: 'Round',
          value: ScoringRules.formatPoints(roundScore.total),
        ),
        _ScoreChip(
          label: 'Total',
          value: ScoringRules.formatPoints(gameScore.total),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text('$label: $value', style: AppText.bodySmall),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.line});

  final AnswerLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 36,
            decoration: BoxDecoration(
              color: line.category.color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.category.label, style: AppText.bodySmall),
                Text(
                  line.isEmpty ? 'No answer' : line.text,
                  style: AppText.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _VerdictChip(verdict: line.verdict),
          SizedBox(
            width: 48,
            child: Text(
              ScoringRules.formatPoints(line.points),
              textAlign: TextAlign.end,
              style: AppText.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.verdict});

  final AnswerVerdict? verdict;

  @override
  Widget build(BuildContext context) {
    final (label, background, text) = switch (verdict) {
      AnswerVerdict.valid => ('Valid', AppColors.valid, Colors.white),
      AnswerVerdict.invalid => ('Invalid', AppColors.invalid, Colors.white),
      AnswerVerdict.disputed => ('Tied', AppColors.lavender, AppColors.navy),
      null => ('Empty', AppColors.disabled, AppColors.navy),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppText.bodySmall.copyWith(color: text)),
    );
  }
}
