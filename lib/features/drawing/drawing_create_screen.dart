import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../models/drawing_room.dart';
import '../../models/room.dart';
import '../../services/drawing/drawing_providers.dart';
import '../../services/game_service.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import '../lobby/room_form_widgets.dart';

/// Opens a Guess the Drawing room on this phone, for friends nearby or
/// online.
class DrawingCreateScreen extends ConsumerStatefulWidget {
  const DrawingCreateScreen({super.key});

  @override
  ConsumerState<DrawingCreateScreen> createState() =>
      _DrawingCreateScreenState();
}

class _DrawingCreateScreenState extends ConsumerState<DrawingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(profileProvider).name,
  );
  int _playerCount = 4;
  int _rounds = DrawingSettings.defaultRounds;
  int _drawSeconds = DrawingSettings.defaultDrawSeconds;
  WordLevel _wordLevel = WordLevel.easy;
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
          .read(drawingServiceProvider)
          .createRoom(
            playerName: name,
            avatarIndex: profile.avatarIndex,
            capacity: _playerCount,
            settings: DrawingSettings(
              rounds: _rounds,
              drawSeconds: _drawSeconds,
              wordLevel: _wordLevel,
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
                  // Bots can't draw or see a drawing, so friends only.
                  RoomModePicker(
                    selected: _mode,
                    allowPractice: false,
                    onChanged: (mode) => setState(() => _mode = mode),
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
              sticker: SvgPicture.asset(AppAssets.star, width: 44),
              foldedCorner: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NumberPicker(
                    label: 'How many rounds?',
                    options: DrawingSettings.roundOptions,
                    selected: _rounds,
                    onChanged: (rounds) => setState(() => _rounds = rounds),
                    keyPrefix: 'round-count',
                    unit: 'rounds',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NumberPicker(
                    label: 'Time to draw',
                    options: DrawingSettings.drawSecondsOptions,
                    selected: _drawSeconds,
                    onChanged: (seconds) =>
                        setState(() => _drawSeconds = seconds),
                    keyPrefix: 'draw-time',
                    unit: 'seconds',
                    suffix: 's',
                    tileWidth: 80,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  WordLevelPicker(
                    selected: _wordLevel,
                    onChanged: (level) => setState(() => _wordLevel = level),
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
