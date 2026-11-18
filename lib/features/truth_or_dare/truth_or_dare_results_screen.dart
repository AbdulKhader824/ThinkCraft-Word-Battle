import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/truth_or_dare_game.dart';
import '../../services/rules/drawing_rules.dart';
import '../../services/rules/truth_or_dare_rules.dart';
import '../../services/sound_service.dart';
import '../../services/truth_or_dare_providers.dart';
import 'truth_or_dare_play_screen.dart';

/// The winner, the awards and everyone's score, with Play Again.
class TruthOrDareResultsScreen extends ConsumerStatefulWidget {
  const TruthOrDareResultsScreen({super.key});

  @override
  ConsumerState<TruthOrDareResultsScreen> createState() =>
      _TruthOrDareResultsScreenState();
}

class _TruthOrDareResultsScreenState
    extends ConsumerState<TruthOrDareResultsScreen> {
  bool _playedFanfare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playedFanfare) return;
    _playedFanfare = true;
    final game = ref.read(truthOrDareProvider);
    final someoneWon =
        game != null && TruthOrDareRules.winners(game).isNotEmpty;
    playSound(ref, someoneWon ? GameSound.win : GameSound.results);
  }

  void _home() {
    ref.read(truthOrDareProvider.notifier).clear();
    goBackOrHome(context);
  }

  void _playAgain() {
    ref.read(truthOrDareProvider.notifier).playAgain();
    context.pushReplacement(AppRoutes.truthOrDarePlay);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(truthOrDareProvider);
    if (game == null) return const SizedBox.shrink();

    final ranked = DrawingRules.rank(
      {
        for (final (index, player) in game.players.indexed)
          '$index': player.points,
      },
      [for (var index = 0; index < game.players.length; index++) '$index'],
    );
    final winners = TruthOrDareRules.winners(game);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
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
                        child: _WinnerBanner(game: game, winners: winners),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Entrance(index: 1, child: _Awards(game: game)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Scores', style: AppText.heading),
                      const SizedBox(height: AppSpacing.xs),
                      for (final (place, entry) in ranked.indexed) ...[
                        Entrance(
                          index: place + 2,
                          child: _PlayerLine(
                            player: game.players[int.parse(entry.playerId)],
                            rank: entry.rank,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GameButton(
                        label: 'Play Again',
                        icon: Icons.replay_rounded,
                        compact: true,
                        onPressed: _playAgain,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      GameButton(
                        label: 'Return Home',
                        icon: Icons.home_rounded,
                        style: GameButtonStyle.sky,
                        compact: true,
                        onPressed: _home,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (winners.isNotEmpty)
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
  const _WinnerBanner({required this.game, required this.winners});

  final TodGame game;
  final List<int> winners;

  @override
  Widget build(BuildContext context) {
    final String headline;
    if (winners.isEmpty) {
      headline = 'Game over!';
    } else if (winners.length > 1) {
      headline = "It's a tie!";
    } else {
      headline = '${game.players[winners.single].name} wins!';
    }
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
            winners.isEmpty
                ? 'Nobody scored this time.'
                : 'The most truths and dares done',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Bravest and Most Honest.
class _Awards extends StatelessWidget {
  const _Awards({required this.game});

  final TodGame game;

  String _names(List<int> places) =>
      [for (final place in places) game.players[place].name].join(' & ');

  @override
  Widget build(BuildContext context) {
    final bravest = TruthOrDareRules.bravest(game);
    final honest = TruthOrDareRules.mostHonest(game);
    if (bravest.isEmpty && honest.isEmpty) return const SizedBox.shrink();

    Widget award(String emoji, String title, List<int> who, String detail) {
      return Row(
        children: [
          Text(emoji, style: AppText.title),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label),
                Text(_names(who), style: AppText.heading),
                Text(detail, style: AppText.bodySmall),
              ],
            ),
          ),
        ],
      );
    }

    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bravest.isNotEmpty)
            award(
              '⚡',
              'Bravest',
              bravest,
              '${game.players[bravest.first].dares} dares done',
            ),
          if (bravest.isNotEmpty && honest.isNotEmpty)
            const SizedBox(height: AppSpacing.xs),
          if (honest.isNotEmpty)
            award(
              '💬',
              'Most Honest',
              honest,
              '${game.players[honest.first].truths} truths answered',
            ),
        ],
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({required this.player, required this.rank});

  final TodPlayer player;
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
    return GameCard(
      color: AppColors.cream,
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
            opacity: player.isOut ? 0.5 : 1,
            child: PlayerAvatar(index: player.avatarIndex, size: 48),
          ),
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
                Text(
                  '${player.truths} truths · ${player.dares} dares'
                  '${player.isOut ? ' · out' : ''}',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          Lives(player: player, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text('${player.points}', style: AppText.heading),
        ],
      ),
    );
  }
}
