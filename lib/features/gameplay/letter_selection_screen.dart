import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/letter_badge.dart';
import '../../models/room.dart';
import '../../services/game_providers.dart';
import '../../services/rules/game_rules.dart';
import '../../services/sound_service.dart';
import 'category_style.dart';
import 'leave_game_guard.dart';

class LetterSelectionScreen extends ConsumerWidget {
  const LetterSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(gameRoomProvider);
    final round = room?.round;
    final myId = ref.watch(gameServiceProvider).localPlayerId;
    if (room == null || round == null) return const SizedBox.shrink();

    final letter = round.letter;
    final isPicker = round.pickerId == myId;

    return LeaveGameGuard(
      child: GameScreen(
        title: letter == null ? 'Pick a Letter' : 'Get Ready!',
        onBack: () => confirmLeaveGame(context, ref),
        child: letter != null
            ? _LetterReveal(letter: letter)
            : _LetterChoice(room: room, isPicker: isPicker),
      ),
    );
  }
}

class _LetterChoice extends ConsumerWidget {
  const _LetterChoice({required this.room, required this.isPicker});

  static const _colors = [
    AppColors.mint,
    AppColors.sky,
    AppColors.sunshine,
    AppColors.coral,
    AppColors.lavender,
    AppColors.peach,
  ];
  static const _minTile = AppSizes.minTapTarget;
  static const _gap = AppSpacing.xs;

  final Room room;
  final bool isPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picker = room.playerById(room.round!.pickerId);
    final service = ref.read(gameServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          roundLabel(room),
          textAlign: TextAlign.center,
          style: AppText.label,
        ),
        Text(
          isPicker
              ? 'Choose the letter for everyone!'
              : '${picker.name} is choosing the letter...',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = ((constraints.maxWidth + _gap) / (_minTile + _gap))
                .floor()
                .clamp(4, 6);
            final tile =
                (constraints.maxWidth - _gap * (columns - 1)) / columns;

            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              alignment: WrapAlignment.center,
              children: [
                for (final (index, letter) in GameRules.letters.indexed)
                  _LetterTile(
                    letter: letter,
                    size: tile,
                    color: _colors[index % _colors.length],
                    isUsed: room.usedLetters.contains(letter),
                    onTap: isPicker && !room.usedLetters.contains(letter)
                        ? () {
                            playSound(ref, GameSound.select);
                            service.selectLetter(letter);
                          }
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.size,
    required this.color,
    required this.isUsed,
    required this.onTap,
  });

  final String letter;
  final double size;
  final Color color;
  final bool isUsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: isUsed ? 'Letter $letter, already played' : 'Letter $letter',
      excludeSemantics: true,
      child: Material(
        color: isUsed ? AppColors.disabled : color,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey('letter-$letter'),
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: Text(
                letter,
                textScaler: TextScaler.noScaling,
                style: AppText.title.copyWith(
                  fontSize: size * 0.5,
                  color: isUsed ? AppColors.disabledText : AppColors.navy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pops the chosen letter onto the screen.
class _LetterReveal extends ConsumerStatefulWidget {
  const _LetterReveal({required this.letter});

  final String letter;

  @override
  ConsumerState<_LetterReveal> createState() => _LetterRevealState();
}

class _LetterRevealState extends ConsumerState<_LetterReveal> {
  @override
  void initState() {
    super.initState();
    playSound(ref, GameSound.reveal);
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? 1 : 0.3, end: 1),
          duration: AppDurations.slow,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.rotate(
            angle: (1 - scale) * 0.8,
            child: Transform.scale(scale: scale, child: child),
          ),
          child: LetterBadge(letter: letter, size: 160),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'The letter is $letter!',
          textAlign: TextAlign.center,
          style: AppText.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Think of words that start with $letter.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      ],
    );
  }
}
