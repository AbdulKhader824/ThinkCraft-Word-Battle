import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/truth_or_dare_game.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import '../../services/truth_or_dare_providers.dart';
import '../lobby/room_form_widgets.dart';

/// Who is playing, how many rounds and which cards, then Start.
class TruthOrDareSetupScreen extends ConsumerStatefulWidget {
  const TruthOrDareSetupScreen({super.key});

  @override
  ConsumerState<TruthOrDareSetupScreen> createState() =>
      _TruthOrDareSetupScreenState();
}

class _TruthOrDareSetupScreenState
    extends ConsumerState<TruthOrDareSetupScreen> {
  final _nameController = TextEditingController();
  late final List<String> _names = [
    if (RoomInputRules.validateName(ref.read(profileProvider).name) == null)
      RoomInputRules.cleanName(ref.read(profileProvider).name),
  ];
  int _rounds = TodSettings.defaultRounds;
  TodLevel _level = TodLevel.kids;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _full => _names.length >= TodGame.maxPlayers;

  void _addName() {
    final error = RoomInputRules.validateName(_nameController.text);
    final name = RoomInputRules.cleanName(_nameController.text);
    String? problem = error;
    final same = _names.where(
      (other) => other.toLowerCase() == name.toLowerCase(),
    );
    if (problem == null && same.isNotEmpty) {
      problem = '${same.first} is already playing.';
    }
    if (problem == null && _full) {
      problem = 'That\'s the most players: ${TodGame.maxPlayers}.';
    }
    setState(() {
      _nameError = problem;
      if (problem == null) {
        _names.add(name);
        _nameController.clear();
      }
    });
  }

  void _start() {
    ref
        .read(truthOrDareProvider.notifier)
        .start(_names, TodSettings(rounds: _rounds, level: _level));
    context.pushReplacement(AppRoutes.truthOrDarePlay);
  }

  @override
  Widget build(BuildContext context) {
    final missing = TodGame.minPlayers - _names.length;
    return GameScreen(
      title: 'Players',
      onBack: () => goBackOrHome(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Who is playing? (${_names.length} of ${TodGame.maxPlayers})',
                  style: AppText.label,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GameTextField(
                        hint: 'Type a name',
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        enabled: !_full,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            RoomInputRules.maxNameLength,
                          ),
                        ],
                        onSubmitted: (_) => _addName(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 104,
                      child: GameButton(
                        key: const ValueKey('add-player'),
                        label: 'Add',
                        icon: Icons.person_add_rounded,
                        compact: true,
                        style: GameButtonStyle.sky,
                        onPressed: _full ? null : _addName,
                      ),
                    ),
                  ],
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _nameError!,
                    style: AppText.bodySmall.copyWith(color: AppColors.invalid),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final name in _names)
                      InputChip(
                        key: ValueKey('player-$name'),
                        label: Text(name, style: AppText.label),
                        backgroundColor: AppColors.backgroundMint,
                        deleteIcon: const Icon(Icons.close_rounded, size: 20),
                        deleteButtonTooltipMessage: 'Remove $name',
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onDeleted: () => setState(() => _names.remove(name)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NumberPicker(
                  label: 'How many rounds?',
                  options: TodSettings.roundOptions,
                  selected: _rounds,
                  onChanged: (rounds) => setState(() => _rounds = rounds),
                  keyPrefix: 'round-count',
                  unit: 'rounds',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Which cards?', style: AppText.label),
                const SizedBox(height: AppSpacing.xs),
                for (final level in TodLevel.values) ...[
                  _LevelOption(
                    key: ValueKey('level-${level.name}'),
                    level: level,
                    selected: level == _level,
                    onTap: () => setState(() => _level = level),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (missing > 0) ...[
            Text(
              missing == 1
                  ? 'Add 1 more player to start.'
                  : 'Add $missing more players to start.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          GameButton(
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            onPressed: missing > 0 ? null : _start,
          ),
        ],
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({
    super.key,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final TodLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    return Semantics(
      button: true,
      selected: selected,
      label: '${level.label}. ${level.detail}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.mint : AppColors.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.navy : AppColors.outline,
                width: selected ? 3 : 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.label, style: AppText.label),
                      Text(level.detail, style: AppText.bodySmall),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.navy,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
