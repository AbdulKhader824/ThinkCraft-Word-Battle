import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/most_likely_room.dart';
import '../../models/room.dart';
import '../../services/game_service.dart';
import '../../services/most_likely/most_likely_providers.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import '../lobby/room_form_widgets.dart';

/// Opens a Most Likely To... room on this phone, for friends nearby or
/// online.
class MostLikelyCreateScreen extends ConsumerStatefulWidget {
  const MostLikelyCreateScreen({super.key});

  @override
  ConsumerState<MostLikelyCreateScreen> createState() =>
      _MostLikelyCreateScreenState();
}

class _MostLikelyCreateScreenState
    extends ConsumerState<MostLikelyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(profileProvider).name,
  );
  int _playerCount = 5;
  int _questions = MostLikelySettings.defaultQuestions;
  Set<MostLikelyTopic> _topics = MostLikelyTopic.values.toSet();
  bool _creating = false;

  /// Friends nearby or online. Bots have no opinions, so no practice.
  RoomMode _mode = RoomMode.nearby;

  bool get _online => _mode == RoomMode.online;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Remembers the name, then opens the room. The router moves to the
  /// lobby by itself, because the game's phase has changed.
  Future<void> _submit() async {
    if (_creating || !_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final profile = ref.read(profileProvider).copyWith(name: name);
    await ref.read(profileProvider.notifier).save(profile);
    setState(() => _creating = true);
    try {
      await ref
          .read(mostLikelyServiceProvider)
          .createRoom(
            playerName: name,
            avatarIndex: profile.avatarIndex,
            capacity: _playerCount,
            settings: MostLikelySettings(
              questions: _questions,
              topics: _topics,
            ),
            online: _online,
          );
    } on JoinRefused catch (error) {
      if (mounted) {
        await showGameMessage(
          context,
          title: "Couldn't open the room",
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'Create Room',
      onBack: () => goBackOrHome(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameCard(
              sticker: SvgPicture.asset(AppAssets.pencil, width: 56),
              foldedCorner: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameTextField(
                    label: 'Your name',
                    hint: 'Type your name',
                    controller: _nameController,
                    validator: RoomInputRules.validateName,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        RoomInputRules.maxNameLength,
                      ),
                    ],
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Bots can't vote about friends, so friends only.
                  RoomModePicker(
                    selected: _mode,
                    allowPractice: false,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NumberPicker(
                    label: 'How many players?',
                    options: [
                      for (
                        var count = MostLikelyRoom.minPlayers;
                        count <= RoomInputRules.maxPlayers;
                        count++
                      )
                        count,
                    ],
                    selected: _playerCount,
                    onChanged: (count) => setState(() => _playerCount = count),
                    keyPrefix: 'player-count',
                    unit: 'players',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GameCard(
              sticker: SvgPicture.asset(AppAssets.star, width: 44),
              foldedCorner: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NumberPicker(
                    label: 'How many questions?',
                    options: MostLikelySettings.questionOptions,
                    selected: _questions,
                    onChanged: (count) => setState(() => _questions = count),
                    keyPrefix: 'question-count',
                    unit: 'questions',
                    tileWidth: 72,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  QuestionTopicPicker(
                    selected: _topics,
                    onChanged: (topics) => setState(() => _topics = topics),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_online) const OnlineModeNote() else const NearbyModeNote(),
            if (_creating && _online) ...[
              const SizedBox(height: AppSpacing.sm),
              const OnlineConnectingNote(),
            ],
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: _creating ? 'Opening...' : 'Create Room',
              icon: Icons.add_circle_rounded,
              onPressed: _creating ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggles for the question topics, two across. At least one stays
/// chosen.
class QuestionTopicPicker extends StatelessWidget {
  const QuestionTopicPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<MostLikelyTopic> selected;
  final ValueChanged<Set<MostLikelyTopic>> onChanged;

  void _toggle(MostLikelyTopic topic) {
    if (!selected.contains(topic)) {
      onChanged({...selected, topic});
    } else if (selected.length > 1) {
      onChanged({...selected}..remove(topic));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question topics (${selected.length} of '
          '${MostLikelyTopic.values.length})',
          style: AppText.label,
        ),
        Text('Pick your fun! Choose at least 1.', style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.xs) / 2;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final topic in MostLikelyTopic.values)
                  SizedBox(
                    width: width,
                    child: _TopicToggle(
                      key: ValueKey('topic-${topic.name}'),
                      topic: topic,
                      selected: selected.contains(topic),
                      onTap: () => _toggle(topic),
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

class _TopicToggle extends StatelessWidget {
  const _TopicToggle({
    super.key,
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final MostLikelyTopic topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    return Semantics(
      button: true,
      selected: selected,
      label: topic.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.mint : AppColors.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.navy : AppColors.outline,
                width: selected ? 3 : 2,
              ),
            ),
            child: Row(
              children: [
                Text(topic.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(topic.label, style: AppText.label)),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.navy,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
