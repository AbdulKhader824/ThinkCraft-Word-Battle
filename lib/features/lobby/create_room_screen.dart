import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/category.dart';
import '../../models/game_settings.dart';
import '../../services/game_providers.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import 'room_form_widgets.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(profileProvider).name,
  );
  int _playerCount = 4;
  int _rounds = GameSettings.defaultRounds;
  int _answerSeconds = GameSettings.defaultAnswerSeconds;
  Set<Category> _categories = Category.values.toSet();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Remembers the name, then creates the room. The router moves to the
  /// Lobby by itself, because the game's phase has changed.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final profile = ref.read(profileProvider).copyWith(name: name);
    await ref.read(profileProvider.notifier).save(profile);
    await ref
        .read(gameServiceProvider)
        .createRoom(
          playerName: name,
          playerCount: _playerCount,
          avatarIndex: profile.avatarIndex,
          settings: GameSettings(
            rounds: _rounds,
            answerSeconds: _answerSeconds,
            categories: _categories,
          ),
        );
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
                  PlayerCountPicker(
                    selected: _playerCount,
                    onChanged: (count) => setState(() => _playerCount = count),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GameCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoundCountPicker(
                    selected: _rounds,
                    onChanged: (rounds) => setState(() => _rounds = rounds),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnswerTimePicker(
                    selected: _answerSeconds,
                    onChanged: (seconds) =>
                        setState(() => _answerSeconds = seconds),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CategoryPicker(
                    selected: _categories,
                    onChanged: (chosen) => setState(() => _categories = chosen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const PracticeModeNote(),
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: 'Create Room',
              icon: Icons.add_circle_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
