import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_card.dart';
import '../../models/category.dart';
import '../../models/game_settings.dart';
import '../../services/rules/room_input_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';

/// Keeps a room code in capitals and blocks characters it can't contain.
class RoomCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final code = RoomInputRules.normalizeRoomCode(newValue.text);
    final limited = code.length > RoomInputRules.roomCodeLength
        ? code.substring(0, RoomInputRules.roomCodeLength)
        : code;
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}

/// Makes it clear that these rooms are simulated, not online.
class PracticeModeNote extends StatelessWidget {
  const PracticeModeNote({super.key});

  @override
  Widget build(BuildContext context) {
    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_rounded, color: AppColors.navy, size: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Practice mode: you play against simulated players on this '
              'device. Online play comes later.',
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label for the Lobby, where space is tight.
class PracticeModeChip extends StatelessWidget {
  const PracticeModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.sunshine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy_rounded, color: AppColors.navy, size: 18),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              'Practice mode: simulated players',
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large number tiles for choosing how many players are in the room.
class PlayerCountPicker extends StatelessWidget {
  const PlayerCountPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NumberPicker(
      label: 'How many players?',
      options: [
        for (
          var count = RoomInputRules.minPlayers;
          count <= RoomInputRules.maxPlayers;
          count++
        )
          count,
      ],
      selected: selected,
      onChanged: onChanged,
      keyPrefix: 'player-count',
      unit: 'players',
    );
  }
}

/// Large number tiles for choosing how many rounds the game lasts.
class RoundCountPicker extends StatelessWidget {
  const RoundCountPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NumberPicker(
      label: 'How many rounds?',
      options: GameSettings.roundOptions,
      selected: selected,
      onChanged: onChanged,
      keyPrefix: 'round-count',
      unit: 'rounds',
    );
  }
}

/// Big tiles for choosing how long each round's timer runs.
class AnswerTimePicker extends StatelessWidget {
  const AnswerTimePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NumberPicker(
      label: 'Time to answer',
      options: GameSettings.answerSecondsOptions,
      selected: selected,
      onChanged: onChanged,
      keyPrefix: 'answer-time',
      unit: 'seconds',
      suffix: 's',
      tileWidth: 72,
    );
  }
}

/// A row of big number tiles where exactly one is chosen.
class NumberPicker extends StatelessWidget {
  const NumberPicker({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    required this.unit,
    this.suffix = '',
    this.tileWidth = AppSizes.minTapTarget,
  });

  /// Shown after the number on the tile, such as "s" for seconds.
  final String suffix;

  /// Wider tiles fit labels like "90s".
  final double tileWidth;

  final String label;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Tiles get keys like `round-count-5`, for tests.
  final String keyPrefix;

  /// Read aloud after the number, such as "5 rounds".
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final count in options)
              _CountTile(
                key: ValueKey('$keyPrefix-$count'),
                count: count,
                unit: unit,
                suffix: suffix,
                width: tileWidth,
                selected: count == selected,
                onTap: () => onChanged(count),
              ),
          ],
        ),
      ],
    );
  }
}

/// Toggles for the categories in the game. At least one stays chosen.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<Category> selected;
  final ValueChanged<Set<Category>> onChanged;

  void _toggle(Category category) {
    if (!selected.contains(category)) {
      onChanged({...selected, category});
    } else if (selected.length > 1) {
      onChanged({...selected}..remove(category));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories (${selected.length} of ${Category.values.length})',
          style: AppText.label,
        ),
        Text('Pick at least 1.', style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.xs) / 2;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final category in Category.values)
                  SizedBox(
                    width: width,
                    child: _CategoryToggle(
                      category: category,
                      selected: selected.contains(category),
                      onTap: () => _toggle(category),
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

class _CategoryToggle extends StatelessWidget {
  const _CategoryToggle({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        decoration: BoxDecoration(
          color: selected ? category.color : AppColors.background,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.outline,
            width: selected ? 3 : 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('category-${category.name}'),
            borderRadius: radius,
            onTap: () {
              playSoundFrom(context, GameSound.select);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: selected ? 1 : 0.45,
                    child: SvgPicture.asset(
                      category.character,
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(category.label, style: AppText.bodySmall),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    super.key,
    required this.count,
    required this.unit,
    required this.suffix,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String unit;
  final String suffix;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '$count $unit',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        width: width,
        height: AppSizes.minTapTarget,
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.background,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.mintDeep : AppColors.outline,
            width: 3,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              playSoundFrom(context, GameSound.select);
              onTap();
            },
            // Shrinks rather than overflows with large system text.
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$count$suffix', style: AppText.heading),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
