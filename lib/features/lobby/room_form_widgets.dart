import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_card.dart';
import '../../services/rules/room_input_rules.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How many players?', style: AppText.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (
              var count = RoomInputRules.minPlayers;
              count <= RoomInputRules.maxPlayers;
              count++
            )
              _CountTile(
                count: count,
                selected: count == selected,
                onTap: () => onChanged(count),
              ),
          ],
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '$count players',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        width: AppSizes.minTapTarget,
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
            key: ValueKey('player-count-$count'),
            borderRadius: radius,
            onTap: onTap,
            child: Center(child: Text('$count', style: AppText.heading)),
          ),
        ),
      ),
    );
  }
}
