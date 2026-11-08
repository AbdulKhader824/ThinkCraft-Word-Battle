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
import '../../models/category.dart';
import '../../models/game_settings.dart';
import '../../models/room.dart';
import '../../services/game_providers.dart';
import '../../services/game_service.dart';
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

  /// Practice first, so the button always starts a game, even with no
  /// friends or Wi-Fi around.
  RoomMode _mode = RoomMode.practice;

  /// For a nearby room: whether bots take the seats friends don't.
  bool _fillWithBots = false;
  bool _creating = false;
  int _rounds = GameSettings.defaultRounds;
  int _answerSeconds = GameSettings.defaultAnswerSeconds;
  Set<Category> _categories = Category.startingPicks.toSet();
  AnswerCheck _answerCheck = AnswerCheck.smart;
  BotLevel _botLevel = BotLevel.medium;

  /// Practice rooms always have bots; nearby ones only when they fill the
  /// empty seats.
  bool get _hasBots => _mode == RoomMode.practice || _fillWithBots;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Remembers the name, then creates the room. The router moves to the
  /// Lobby by itself, because the game's phase has changed.
  Future<void> _submit() async {
    if (_creating || !_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final profile = ref.read(profileProvider).copyWith(name: name);
    await ref.read(profileProvider.notifier).save(profile);
    setState(() => _creating = true);
    try {
      await ref
          .read(gameServiceProvider)
          .createRoom(
            playerName: name,
            playerCount: _playerCount,
            avatarIndex: profile.avatarIndex,
            mode: _mode,
            fillWithBots: _mode == RoomMode.nearby && _fillWithBots,
            settings: GameSettings(
              rounds: _rounds,
              answerSeconds: _answerSeconds,
              categories: _categories,
              answerCheck: _answerCheck,
              botLevel: _botLevel,
            ),
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
                  RoomModePicker(
                    selected: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  // In practice the count is you plus bots. In a nearby
                  // room it's the room's size: friends fill it, and bots
                  // can take the seats left over.
                  const SizedBox(height: AppSpacing.lg),
                  PlayerCountPicker(
                    selected: _playerCount,
                    onChanged: (count) => setState(() => _playerCount = count),
                  ),
                  if (_mode == RoomMode.nearby) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FillWithBotsSwitch(
                      value: _fillWithBots,
                      onChanged: (on) => setState(() => _fillWithBots = on),
                    ),
                  ],
                  if (_hasBots) ...[
                    const SizedBox(height: AppSpacing.lg),
                    BotLevelPicker(
                      selected: _botLevel,
                      onChanged: (level) => setState(() => _botLevel = level),
                    ),
                  ],
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
                  const SizedBox(height: AppSpacing.lg),
                  AnswerCheckPicker(
                    selected: _answerCheck,
                    onChanged: (check) => setState(() => _answerCheck = check),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_mode == RoomMode.nearby)
              const NearbyModeNote()
            else
              const PracticeModeNote(),
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
