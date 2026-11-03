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

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final code = _codeController.text;
    ref
        .read(roomEntryProvider.notifier)
        .save(RoomEntry.join(playerName: name, roomCode: code));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Code $code accepted! The Lobby comes next.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'Join Room',
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
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        RoomInputRules.maxNameLength,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GameTextField(
                    label: 'Room code',
                    hint: 'ABC234',
                    controller: _codeController,
                    validator: RoomInputRules.validateRoomCode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [RoomCodeFormatter()],
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const PracticeModeNote(),
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: 'Join Room',
              icon: Icons.login_rounded,
              style: GameButtonStyle.sunshine,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
