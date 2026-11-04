import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/candy_tile.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/game_card.dart';
import '../../models/category.dart';
import '../../models/game_settings.dart';
import '../../services/rules/room_input_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';
import '../gameplay/category_picture.dart';

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
      label: 'How much time?',
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
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.lg,
          children: [
            for (final (index, count) in options.indexed)
              _CountTile(
                key: ValueKey('$keyPrefix-$count'),
                count: count,
                color: AppColors.candy[index % AppColors.candy.length],
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
        Text('Pick your fun! Choose at least 1.', style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.xs) / 2;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.md,
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
    final duration = reduceMotion ? Duration.zero : AppDurations.fast;

    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1 : 0.96,
        duration: duration,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                color: selected ? category.color : AppColors.disabled,
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
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Unchosen pictures fade, so the chosen ones stand out.
                        AnimatedOpacity(
                          opacity: selected ? 1 : 0.4,
                          duration: duration,
                          child: LayoutBuilder(
                            builder: (context, constraints) => CategoryPicture(
                              category: category,
                              height:
                                  constraints.maxWidth /
                                  CategoryPicture.aspectRatio,
                            ),
                          ),
                        ),
                        // A solid strip keeps the name readable.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs,
                            vertical: AppSpacing.xxs,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.label,
                                  style: AppText.label,
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: AppColors.navy,
                                size: 24,
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
            if (selected)
              Positioned(
                top: -AppSpacing.sm,
                right: -AppSpacing.xs,
                child: IgnorePointer(
                  child: SvgPicture.asset(AppAssets.star, width: 34),
                ),
              ),
          ],
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
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String unit;
  final String suffix;
  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CandyTile(
      label: '$count$suffix',
      color: color,
      selected: selected,
      width: width,
      semanticsLabel: '$count $unit',
      onTap: () {
        playSoundFrom(context, GameSound.select);
        onTap();
      },
    );
  }
}
