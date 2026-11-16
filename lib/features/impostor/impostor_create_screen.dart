import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/category.dart';
import '../../models/impostor_room.dart';
import '../../models/room.dart';
import '../../services/game_service.dart';
import '../../services/impostor/impostor_providers.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import '../lobby/room_form_widgets.dart';

/// Opens an Impostor room on this phone, for friends nearby or online.
class ImpostorCreateScreen extends ConsumerStatefulWidget {
  const ImpostorCreateScreen({super.key});

  @override
  ConsumerState<ImpostorCreateScreen> createState() =>
      _ImpostorCreateScreenState();
}

class _ImpostorCreateScreenState extends ConsumerState<ImpostorCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(profileProvider).name,
  );
  int _playerCount = 5;
  int _rounds = ImpostorSettings.defaultRounds;
  int _clueSeconds = ImpostorSettings.defaultClueSeconds;
  int _clueTurns = ImpostorSettings.defaultClueTurns;
  Set<ImpostorTopic> _topics = ImpostorTopic.values.toSet();
  bool _creating = false;

  /// Friends nearby or online. Bots can't play, so no practice.
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
          .read(impostorServiceProvider)
          .createRoom(
            playerName: name,
            avatarIndex: profile.avatarIndex,
            capacity: _playerCount,
            settings: ImpostorSettings(
              rounds: _rounds,
              clueSeconds: _clueSeconds,
              clueTurns: _clueTurns,
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
                  // Bots can't talk, so friends only.
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
                        var count = ImpostorRoom.minPlayers;
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
                    label: 'How many rounds?',
                    options: ImpostorSettings.roundOptions,
                    selected: _rounds,
                    onChanged: (rounds) => setState(() => _rounds = rounds),
                    keyPrefix: 'round-count',
                    unit: 'rounds',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NumberPicker(
                    label: 'Time for each clue',
                    options: ImpostorSettings.clueSecondsOptions,
                    selected: _clueSeconds,
                    onChanged: (seconds) =>
                        setState(() => _clueSeconds = seconds),
                    keyPrefix: 'clue-time',
                    unit: 'seconds',
                    suffix: 's',
                    tileWidth: 72,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NumberPicker(
                    label: 'Clue turns each',
                    options: ImpostorSettings.clueTurnsOptions,
                    selected: _clueTurns,
                    onChanged: (turns) => setState(() => _clueTurns = turns),
                    keyPrefix: 'clue-turns',
                    unit: 'turns',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TopicPicker(
                    selected: _topics,
                    onChanged: (topics) => setState(() => _topics = topics),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_online) ...[
              const OnlineModeNote(),
              const SizedBox(height: AppSpacing.sm),
              const VoiceCallNote(),
            ] else
              const NearbyModeNote(),
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

/// The Word Battle category whose picture shows each topic.
extension TopicPicture on ImpostorTopic {
  Category get picture => switch (this) {
    ImpostorTopic.animals => Category.animal,
    ImpostorTopic.food => Category.food,
    ImpostorTopic.places => Category.place,
    ImpostorTopic.things => Category.thing,
    ImpostorTopic.jobs => Category.person,
    ImpostorTopic.sports => Category.sport,
    ImpostorTopic.movies => Category.cartoon,
  };
}

/// Toggles for the word topics, with the same pictures as Word Battle's
/// categories. At least one stays chosen.
class TopicPicker extends StatelessWidget {
  const TopicPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<ImpostorTopic> selected;
  final ValueChanged<Set<ImpostorTopic>> onChanged;

  void _toggle(ImpostorTopic topic) {
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
          'Word topics (${selected.length} of ${ImpostorTopic.values.length})',
          style: AppText.label,
        ),
        Text('Pick your fun! Choose at least 1.', style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            // Two across, with wide pictures, like Word Battle.
            final width = (constraints.maxWidth - AppSpacing.xs) / 2;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.md,
              children: [
                for (final topic in ImpostorTopic.values)
                  SizedBox(
                    width: width,
                    child: CategoryToggle(
                      category: topic.picture,
                      label: topic.label,
                      tapKey: ValueKey('topic-${topic.name}'),
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
