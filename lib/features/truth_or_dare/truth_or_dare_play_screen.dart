import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/truth_or_dare_game.dart';
import '../../services/sound_service.dart';
import '../../services/truth_or_dare_providers.dart';

/// Asks before ending the game early, then shows the results.
Future<void> confirmEndTruthOrDare(BuildContext context, WidgetRef ref) async {
  final confirmed = await showGameConfirm(
    context,
    title: 'End the game?',
    message: 'The game ends now and the scores so far are shown.',
    confirmLabel: 'End Game',
    cancelLabel: 'Keep Playing',
  );
  if (confirmed) ref.read(truthOrDareProvider.notifier).finish();
}

/// A turn of Truth or Dare: the spinner picks a player, they pick Truth or
/// Dare, then the group decides Done or Skip.
class TruthOrDarePlayScreen extends ConsumerWidget {
  const TruthOrDarePlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(truthOrDareProvider);
    ref.listen(truthOrDareProvider, (previous, next) {
      if (next?.phase == TodPhase.finished &&
          previous?.phase != TodPhase.finished) {
        context.pushReplacement(AppRoutes.truthOrDareResults);
      }
    });
    if (game == null || game.phase == TodPhase.finished) {
      return const SizedBox.shrink();
    }
    final player = game.currentPlayer!;
    final notifier = ref.read(truthOrDareProvider.notifier);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmEndTruthOrDare(context, ref);
      },
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
                game: game,
                onEnd: () => confirmEndTruthOrDare(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: game.phase == TodPhase.card
                    ? _CardStage(
                        key: ValueKey('card-${game.card}'),
                        game: game,
                        player: player,
                        onDone: notifier.done,
                        onSkip: notifier.skip,
                        onAnother: notifier.another,
                      )
                    : _ChooseStage(
                        key: ValueKey(
                          'turn-${game.round}-${game.takenThisRound.length}',
                        ),
                        game: game,
                        player: player,
                        onChoose: notifier.choose,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game, required this.onEnd});

  final TodGame game;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(
            tooltip: 'End game',
            iconSize: 26,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget,
            ),
            color: AppColors.navy,
            onPressed: onEnd,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Round ${game.round} of ${game.settings.rounds}',
            style: AppText.label,
          ),
        ),
        Text('${game.stillIn.length} playing', style: AppText.bodySmall),
      ],
    );
  }
}

/// A player's lives, as hearts.
class Lives extends StatelessWidget {
  const Lives({super.key, required this.player, this.size = 22});

  final TodPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final left = player.livesLeft;
    return Semantics(
      label: left == 1 ? '1 life left' : '$left lives left',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var life = 0; life < TodPlayer.lives; life++)
            Icon(
              life < left
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: life < left ? AppColors.invalid : AppColors.outline,
              size: size,
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- choose

/// The spinner lands on the player, then they pick Truth or Dare.
class _ChooseStage extends StatefulWidget {
  const _ChooseStage({
    super.key,
    required this.game,
    required this.player,
    required this.onChoose,
  });

  final TodGame game;
  final TodPlayer player;
  final ValueChanged<TodKind> onChoose;

  @override
  State<_ChooseStage> createState() => _ChooseStageState();
}

class _ChooseStageState extends State<_ChooseStage> {
  /// How many faces the spinner passes before landing.
  static const _hops = 12;

  Timer? _timer;
  int _hop = 0;
  bool _landed = false;

  List<int> get _faces => widget.game.stillIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _landed) return;
    if (MediaQuery.disableAnimationsOf(context) || _faces.length < 2) {
      _landed = true;
      return;
    }
    _spinStep();
  }

  /// Each hop is a little slower, like a spinner running down.
  void _spinStep() {
    _timer = Timer(Duration(milliseconds: 60 + _hop * 18), () {
      if (!mounted) return;
      if (_hop >= _hops) {
        setState(() => _landed = true);
        playSoundFrom(context, GameSound.reveal);
        return;
      }
      setState(() => _hop++);
      playSoundFrom(context, GameSound.tick);
      _spinStep();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Which face is lit: the spinner ends on the chosen player.
  int get _lit {
    final faces = _faces;
    final target = faces.indexOf(widget.game.current!);
    if (_landed) return faces[target];
    final offset = (_hops - _hop) % faces.length;
    return faces[(target - offset) % faces.length];
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final lit = _lit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final index in _faces)
                    AnimatedScale(
                      scale: index == lit ? 1.15 : 1,
                      duration: AppDurations.fast,
                      child: _Face(
                        player: game.players[index],
                        lit: index == lit,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _landed ? 1 : 0,
          duration: AppDurations.medium,
          child: IgnorePointer(
            ignoring: !_landed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "${widget.player.name}'s turn!",
                  key: const ValueKey('turn-name'),
                  textAlign: TextAlign.center,
                  style: AppText.title,
                ),
                Center(child: Lives(player: widget.player)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: GameButton(
                        label: 'Truth',
                        icon: Icons.chat_bubble_rounded,
                        style: GameButtonStyle.sky,
                        onPressed: () => widget.onChoose(TodKind.truth),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GameButton(
                        label: 'Dare',
                        icon: Icons.bolt_rounded,
                        style: GameButtonStyle.coral,
                        onPressed: () => widget.onChoose(TodKind.dare),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.player, required this.lit});

  final TodPlayer player;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: lit ? AppColors.sunshine : AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: lit ? AppColors.navy : AppColors.outline,
          width: lit ? 3 : 2,
        ),
      ),
      child: Column(
        children: [
          PlayerAvatar(index: player.avatarIndex, size: 52),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- card

class _CardStage extends StatelessWidget {
  const _CardStage({
    super.key,
    required this.game,
    required this.player,
    required this.onDone,
    required this.onSkip,
    required this.onAnother,
  });

  final TodGame game;
  final TodPlayer player;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final isTruth = game.kind == TodKind.truth;
    final lastLife = player.livesLeft == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PlayerAvatar(index: player.avatarIndex, size: 48),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(player.name, style: AppText.heading)),
            Lives(player: player),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GameCard(
            color: isTruth ? AppColors.sky : AppColors.coral,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      isTruth ? '💬 TRUTH' : '⚡ DARE',
                      textAlign: TextAlign.center,
                      style: AppText.heading,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      game.card ?? '',
                      key: const ValueKey('card-text'),
                      textAlign: TextAlign.center,
                      style: AppText.title,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
            foregroundColor: AppColors.navy,
          ),
          onPressed: onAnother,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Another card (free)', style: AppText.label),
        ),
        const SizedBox(height: AppSpacing.xxs),
        GameButton(
          label: 'Done!',
          icon: Icons.check_circle_rounded,
          sound: GameSound.lock,
          onPressed: onDone,
        ),
        const SizedBox(height: AppSpacing.xs),
        GameButton(
          label: lastLife ? 'Skip (last life!)' : 'Skip (lose a life)',
          icon: Icons.heart_broken_rounded,
          style: GameButtonStyle.lavender,
          compact: true,
          onPressed: onSkip,
        ),
      ],
    );
  }
}
