import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../services/game_providers.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import 'room_form_widgets.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(profileProvider).name,
  );
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Joins the room. The router then moves to the Lobby by itself, because
  /// the game's phase has changed.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final profile = ref.read(profileProvider).copyWith(name: name);
    await ref.read(profileProvider.notifier).save(profile);
    await ref
        .read(gameServiceProvider)
        .joinRoom(
          playerName: name,
          roomCode: _codeController.text,
          avatarIndex: profile.avatarIndex,
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
