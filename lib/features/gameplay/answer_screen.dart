import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../core/widgets/letter_badge.dart';
import '../../models/category.dart';
import '../../models/room.dart';
import '../../services/game_providers.dart';
import '../../services/rules/game_rules.dart';
import '../../services/sound_service.dart';
import 'category_style.dart';
import 'category_picture.dart';
import 'leave_game_guard.dart';

class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({super.key});

  @override
  ConsumerState<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends ConsumerState<AnswerScreen> {
  final _controllers = {
    for (final category in Category.values) category: TextEditingController(),
  };

  // Android pauses timers in the background, so check the deadline on return.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(gameServiceProvider).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final service = ref.read(gameServiceProvider);
    // Only count the categories in this game, not every answer field.
    final categories =
        ref.read(gameRoomProvider)?.settings.categories ?? Category.values;
    final blanks = categories
        .where((category) => _controllers[category]!.text.trim().isEmpty)
        .length;

    if (blanks > 0) {
      final submit = await showGameConfirm(
        context,
        title: blanks == 1 ? '1 answer is blank' : '$blanks answers are blank',
        message: 'Blank answers score 0 points. Lock in anyway?',
        confirmLabel: 'Lock In',
        cancelLabel: 'Keep Going',
      );
      if (!submit) return;
    }
    if (!mounted) return;
    playSound(ref, GameSound.lock);
    await service.submitAnswers();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(gameRoomProvider);
    final round = room?.round;
    final myId = ref.watch(gameServiceProvider).localPlayerId;
    final letter = round?.letter;
    final deadline = round?.deadline;
    if (room == null || letter == null || deadline == null) {
      return const SizedBox.shrink();
    }

    final locked = round!.submittedPlayerIds.contains(myId);
    final categories = room.settings.categories;
    final service = ref.read(gameServiceProvider);

    return LeaveGameGuard(
      child: GameFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoundHeader(
              letter: letter,
              deadline: deadline,
              total: room.settings.answerTime,
              roundLabel: roundLabel(room),
              locked: locked,
            ),
            // Outside the scrolling list, so it shows even when the
            // player locks in from the bottom of the list.
            if (locked)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: _LockedBanner(room: room),
              ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxs,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, category) in categories.indexed) ...[
                      Entrance(
                        index: index,
                        child: _CategoryCard(
                          category: category,
                          letter: letter,
                          controller: _controllers[category]!,
                          locked: locked,
                          isLast: category == categories.last,
                          onChanged: (text) {
                            service.updateAnswer(category, text);
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (!locked) ...[
                      const SizedBox(height: AppSpacing.xs),
                      GameButton(
                        label: 'Lock In Answers',
                        icon: Icons.lock_rounded,
                        // Locking in plays its own chime instead.
                        sound: null,
                        onPressed: _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stays on screen while the answers scroll, so the timer is always visible.
class _RoundHeader extends ConsumerWidget {
  const _RoundHeader({
    required this.letter,
    required this.deadline,
    required this.total,
    required this.roundLabel,
    required this.locked,
  });

  static const _tickFrom = 5;

  final String letter;
  final DateTime deadline;

  /// The room's answer time, so the ring drains at the right speed.
  final Duration total;
  final String roundLabel;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          LetterBadge(letter: letter),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find $letter words!', style: AppText.heading),
                Text(roundLabel, style: AppText.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CountdownRing(
            deadline: deadline,
            total: total,
            // A soft tick for the last seconds, until answers are locked.
            onSecond: (seconds) {
              if (!locked && seconds > 0 && seconds <= _tickFrom) {
                playSound(ref, GameSound.tick);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final waiting = room.players.length - room.round!.submittedPlayerIds.length;

    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.sunshine, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              waiting == 1
                  ? 'Answers locked! Waiting for 1 more player...'
                  : 'Answers locked! Waiting for $waiting more players...',
              style: AppText.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.letter,
    required this.controller,
    required this.locked,
    required this.isLast,
    required this.onChanged,
  });

  final Category category;
  final String letter;
  final TextEditingController controller;
  final bool locked;
  final bool isLast;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final wrongLetter = !GameRules.startsWithLetter(controller.text, letter);
    final looksGood =
        !locked && !wrongLetter && controller.text.trim().isNotEmpty;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GameCard(
      color: category.color,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CategoryPicture(category: category, height: 44),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(category.label, style: AppText.heading)),
              // A green tick pops in once an answer starts with the letter.
              AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : AppDurations.medium,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: looksGood
                    ? const _Tick(key: ValueKey('tick'))
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              if (locked) const Icon(Icons.lock_rounded, color: AppColors.navy),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GameTextField(
            key: ValueKey('answer-${category.name}'),
            hint: locked ? 'No answer' : 'Starts with $letter',
            controller: controller,
            enabled: !locked,
            textInputAction: isLast
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: onChanged,
          ),
          if (wrongLetter) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.error_rounded,
                  color: AppColors.navy,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    "This doesn't start with $letter.",
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.valid,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 22,
        semanticLabel: 'Starts with the right letter',
      ),
    );
  }
}
