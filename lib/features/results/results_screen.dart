import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
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
import '../gameplay/category_style.dart';
import '../gameplay/leave_game_guard.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(gameRoomProvider);
    final results = room?.round?.results;
    final service = ref.read(gameServiceProvider);
    if (room == null || results == null) return const SizedBox.shrink();

    final ranked = ScoringRules.rank(room.scores, room.playerIds);

    return LeaveGameGuard(
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _WinnerBanner(room: room, ranked: ranked),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Tap a player to see their answers.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final entry in ranked) ...[
                            _PlayerResultCard(
                              player: room.playerById(entry.playerId),
                              rank: entry.rank,
                              gameScore: entry.score,
                              roundScore: results.scores[entry.playerId]!,
                              lines: results.lines[entry.playerId]!,
                              isMe: entry.playerId == service.localPlayerId,
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
                      child: Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: 'Play Again',
                              onPressed: service.playAgain,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: GameButton(
                              label: 'Return Home',
                              style: GameButtonStyle.sky,
                              onPressed: service.leaveRoom,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.room, required this.ranked});

  final Room room;
  final List<LeaderboardEntry> ranked;

  String get _headline {
    final leaders = ranked.where((entry) => entry.rank == 1).toList();
    if (leaders.length > 1) return "It's a tie!";

    final name = room.playerById(leaders.single.playerId).name;
    return room.round!.number == 1 ? '$name wins!' : '$name is leading!';
  }

  @override
  Widget build(BuildContext context) {
    final onNavy = AppText.body.copyWith(color: Colors.white);

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
            _headline,
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: Colors.white),
          ),
          Text('Round ${room.round!.number} results', style: onNavy),
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
  });

  /// Answers worth the full 10 points were unique, which earns a star.
  static const _uniqueAnswerPoints = 1000;

  final Player player;
  final int rank;
  final ScoreLine gameScore;
  final ScoreLine roundScore;
  final List<AnswerLine> lines;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final stars = lines
        .where((line) => line.points == _uniqueAnswerPoints)
        .length;

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
                Text(
                  ScoringRules.formatPoints(gameScore.total),
                  style: AppText.heading,
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
