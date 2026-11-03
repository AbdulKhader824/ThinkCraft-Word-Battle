import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/countdown_ring.dart';
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
import 'category_style.dart';
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
    final blanks = _controllers.values
        .where((controller) => controller.text.trim().isEmpty)
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
    final lastCategory = Category.values.last;
    final service = ref.read(gameServiceProvider);

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
                    _RoundHeader(letter: letter, deadline: deadline),
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
                            for (final category in Category.values) ...[
                              _CategoryCard(
                                category: category,
                                letter: letter,
                                controller: _controllers[category]!,
                                locked: locked,
                                isLast: category == lastCategory,
                                onChanged: (text) {
                                  service.updateAnswer(category, text);
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            if (!locked) ...[
                              const SizedBox(height: AppSpacing.xs),
                              GameButton(
                                label: 'Lock In Answers',
                                icon: Icons.lock_rounded,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Stays on screen while the answers scroll, so the timer is always visible.
class _RoundHeader extends ConsumerWidget {
  const _RoundHeader({required this.letter, required this.deadline});

  final String letter;
  final DateTime deadline;

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
          Expanded(child: Text('Find $letter words!', style: AppText.heading)),
          const SizedBox(width: AppSpacing.sm),
          CountdownRing(deadline: deadline, total: GameRules.answerTime),
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

    return GameCard(
      color: category.color,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgPicture.asset(category.character, width: 44, height: 44),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(category.label, style: AppText.heading)),
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
