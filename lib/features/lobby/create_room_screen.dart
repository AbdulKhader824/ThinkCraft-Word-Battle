import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/room_entry.dart';
import '../../services/rules/room_input_rules.dart';
import 'room_entry_provider.dart';
import 'room_form_widgets.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _playerCount = 4;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    ref
        .read(roomEntryProvider.notifier)
        .save(RoomEntry.create(playerName: name, playerCount: _playerCount));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Room ready, $name! The Lobby comes next.')),
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
