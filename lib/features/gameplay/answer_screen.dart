import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Which category is on screen. Answers are typed one category at a
  /// time, and Next slides in the following one.
  int _step = 0;

  /// Whether the last move went forward, so cards slide the right way.
  bool _forward = true;

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

  void _goTo(int step, int count) {
    if (step == _step || step < 0 || step >= count) return;
    setState(() {
      _forward = step > _step;
      _step = step;
    });
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
              child: locked
                  ? _LockedAnswers(
                      categories: categories,
                      letter: letter,
                      controllers: _controllers,
                    )
                  : _AnswerSteps(
                      categories: categories,
                      letter: letter,
                      step: _step.clamp(0, categories.length - 1),
                      forward: _forward,
                      controllers: _controllers,
                      onChanged: (category, text) {
                        service.updateAnswer(category, text);
                        setState(() {});
                      },
                      onStep: (step) => _goTo(step, categories.length),
                      onLockIn: _submit,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Typing one category at a time: a row of category pictures to show
/// progress, one big card, and Next (or Lock In on the last one).
class _AnswerSteps extends StatelessWidget {
  const _AnswerSteps({
    required this.categories,
    required this.letter,
    required this.step,
    required this.forward,
    required this.controllers,
    required this.onChanged,
    required this.onStep,
    required this.onLockIn,
  });

  static const _slide = Duration(milliseconds: 300);

  final List<Category> categories;
  final String letter;
  final int step;
  final bool forward;
  final Map<Category, TextEditingController> controllers;
  final void Function(Category category, String text) onChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onLockIn;

  @override
  Widget build(BuildContext context) {
    final category = categories[step];
    final isLast = step == categories.length - 1;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // With the keyboard up there's less room, so the picture shrinks.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _StepProgress(
            categories: categories,
            step: step,
            controllers: controllers,
            onTap: onStep,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          // Sliding cards stay inside this area, never over the header.
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : _slide,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              // Next slides the new card in from the right; going back
              // brings it in from the left.
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(category);
                final side = incoming == forward ? 1.0 : -1.0;
                return SlideTransition(
                  position: Tween(
                    begin: Offset(side, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: SingleChildScrollView(
                key: ValueKey(category),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _CategoryCard(
                  category: category,
                  letter: letter,
                  controller: controllers[category]!,
                  locked: false,
                  isLast: isLast,
                  pictureHeight: keyboardUp ? 56 : 110,
                  autofocus: true,
                  onChanged: (text) => onChanged(category, text),
                  onSubmitted: isLast ? null : (_) => onStep(step + 1),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              if (step > 0) ...[
                Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: IconButton(
                    tooltip: 'Previous',
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.mainButton,
                      minHeight: AppSizes.mainButton,
                    ),
                    color: AppColors.navy,
                    onPressed: () {
                      playSoundFrom(context, GameSound.tap);
                      onStep(step - 1);
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: isLast
                    ? GameButton(
                        label: 'Lock In Answers',
                        icon: Icons.lock_rounded,
                        // Locking in plays its own chime instead.
                        sound: null,
                        onPressed: onLockIn,
                      )
                    : GameButton(
                        label: 'Next',
                        icon: Icons.arrow_forward_rounded,
                        style: GameButtonStyle.sky,
                        onPressed: () => onStep(step + 1),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small picture for each category. The current one is outlined, answered
/// ones get a green tick, and tapping one jumps straight to it.
class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.categories,
    required this.step,
    required this.controllers,
    required this.onTap,
  });

  final List<Category> categories;
  final int step;
  final Map<Category, TextEditingController> controllers;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        Row(
          children: [
            for (final (index, category) in categories.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _ProgressChip(
                    category: category,
                    current: index == step,
                    answered: controllers[category]!.text.trim().isNotEmpty,
                    reduceMotion: reduceMotion,
                    onTap: () {
                      if (index != step) {
                        playSoundFrom(context, GameSound.select);
                      }
                      onTap(index);
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text('${step + 1} of ${categories.length}', style: AppText.bodySmall),
      ],
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.category,
    required this.current,
    required this.answered,
    required this.reduceMotion,
    required this.onTap,
  });

  final Category category;
  final bool current;
  final bool answered;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      label: answered ? '${category.label}, answered' : category.label,
      // The label above says it all, so the picture and tick stay quiet.
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('step-${category.name}'),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedScale(
              scale: current ? 1 : 0.88,
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: current ? AppColors.navy : Colors.white,
                    width: current ? 3 : 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: CategoryPicture.aspectRatio,
                    child: FittedBox(
                      child: CategoryPicture(category: category, height: 40),
                    ),
                  ),
                ),
              ),
            ),
            if (answered)
              const Positioned(top: -6, right: -4, child: _Tick(size: 20)),
          ],
        ),
      ),
    );
  }
}

/// After locking in, every answer is shown at once, read-only.
class _LockedAnswers extends StatelessWidget {
  const _LockedAnswers({
    required this.categories,
    required this.letter,
    required this.controllers,
  });

  final List<Category> categories;
  final String letter;
  final Map<Category, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in categories) ...[
            _CategoryCard(
              category: category,
              letter: letter,
              controller: controllers[category]!,
              locked: true,
              isLast: category == categories.last,
              onChanged: (_) {},
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
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
    this.onSubmitted,
    this.pictureHeight,
    this.autofocus = false,
  });

  final Category category;
  final String letter;
  final TextEditingController controller;
  final bool locked;
  final bool isLast;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Set for the big one-at-a-time card, which shows the picture large
  /// above the name. Left null, the picture sits small beside the name.
  final double? pictureHeight;
  final bool autofocus;

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
          if (pictureHeight != null) ...[
            Center(
              child: CategoryPicture(
                category: category,
                height: pictureHeight!,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            children: [
              if (pictureHeight == null)
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
            onSubmitted: onSubmitted,
            autofocus: autofocus,
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
  const _Tick({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.valid,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: size * 0.7,
        semanticLabel: 'Starts with the right letter',
      ),
    );
  }
}
