import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/candy_tile.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/letter_badge.dart';
import '../../core/widgets/player_avatar.dart';
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
            : isPicker
            ? _LetterChoice(room: room)
            : _WaitingForPicker(room: room),
      ),
    );
  }
}

/// What everyone else sees while the picker chooses: who is choosing, and a
/// mystery tile flicking through letters, instead of tiles they can't tap.
class _WaitingForPicker extends StatelessWidget {
  const _WaitingForPicker({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final picker = room.playerById(room.round!.pickerId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          roundLabel(room),
          textAlign: TextAlign.center,
          style: AppText.label,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(child: PlayerAvatar(index: picker.avatarIndex, size: 112)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${picker.name} is choosing the letter...',
          textAlign: TextAlign.center,
          style: AppText.heading,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(child: _MysteryTile(usedLetters: room.usedLetters)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Get ready to think fast!',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      ],
    );
  }
}

/// A big candy tile that flicks through the letters still in play, like a
/// slot machine. With reduced motion it simply shows a question mark.
class _MysteryTile extends StatefulWidget {
  const _MysteryTile({required this.usedLetters});

  final Set<String> usedLetters;

  @override
  State<_MysteryTile> createState() => _MysteryTileState();
}

class _MysteryTileState extends State<_MysteryTile> {
  static const _size = 120.0;
  static const _flick = Duration(milliseconds: 220);

  /// Steps through the alphabet 7 letters at a time, which looks random
  /// but visits every letter, so no random numbers are needed.
  static const _jump = 7;

  Timer? _timer;
  int _position = 0;

  List<String> get _letters {
    final left = GameRules.letters
        .where((letter) => !widget.usedLetters.contains(letter))
        .toList();
    return left.isEmpty ? GameRules.letters : left;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_flick, (_) {
        setState(() => _position += _jump);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    final shuffling = _timer != null;
    final label = shuffling ? letters[_position % letters.length] : '?';
    final color = AppColors.candy[_position % AppColors.candy.length];

    // Changes five times a second, so it repaints on its own.
    // A normal-sized tile scaled up as a whole, so the letter grows with it.
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: _size,
          child: FittedBox(
            child: CandyTile(
              label: label,
              color: color,
              width: AppSizes.minTapTarget,
              height: AppSizes.minTapTarget,
              semanticsLabel: 'Mystery letter',
              onTap: null,
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterChoice extends ConsumerWidget {
  const _LetterChoice({required this.room});

  static const _colors = AppColors.candy;
  static const _minTile = AppSizes.minTapTarget;
  static const _gap = AppSpacing.xs;
  static const _wave = Duration(milliseconds: 18);

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Choose the letter for everyone!',
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
                // The tiles pop in as a quick wave from A to Z.
                for (final (index, letter) in GameRules.letters.indexed)
                  Entrance(
                    index: index,
                    step: _wave,
                    rise: 12,
                    fromScale: 0.5,
                    child: _LetterTile(
                      letter: letter,
                      size: tile,
                      color: _colors[index % _colors.length],
                      isUsed: room.usedLetters.contains(letter),
                      onTap: !room.usedLetters.contains(letter)
                          ? () {
                              playSound(ref, GameSound.select);
                              service.selectLetter(letter);
                            }
                          : null,
                    ),
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
    return CandyTile(
      tapKey: ValueKey('letter-$letter'),
      label: letter,
      color: color,
      used: isUsed,
      width: size,
      height: size,
      semanticsLabel: isUsed
          ? 'Letter $letter, already played'
          : 'Letter $letter',
      onTap: onTap,
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
