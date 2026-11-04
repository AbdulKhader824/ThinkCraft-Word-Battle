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
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/game_text_field.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/player_profile.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import '../../services/sound_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _avatarIndex;
  late bool _soundOn;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _avatarIndex = profile.avatarIndex;
    _soundOn = profile.soundOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// A blank name is allowed here: it just means "ask me each time".
  String? _validateName(String? name) {
    if ((name ?? '').trim().isEmpty) return null;
    return RoomInputRules.validateName(name);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(profileProvider.notifier)
        .save(
          ref
              .read(profileProvider)
              .copyWith(
                soundOn: _soundOn,
                name: RoomInputRules.cleanName(_nameController.text),
                avatarIndex: _avatarIndex,
              ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved!')));
  }

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      title: 'Settings',
      onBack: () => goBackOrHome(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameCard(
              sticker: SvgPicture.asset(AppAssets.pencil, width: 56),
              foldedCorner: true,
              child: GameTextField(
                label: 'Your name',
                hint: 'Type your name',
                controller: _nameController,
                validator: _validateName,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    RoomInputRules.maxNameLength,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GameCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your character', style: AppText.label),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (
                        var index = 0;
                        index < PlayerProfile.avatarCount;
                        index++
                      )
                        _AvatarChoice(
                          index: index,
                          selected: index == _avatarIndex,
                          onTap: () => setState(() => _avatarIndex = index),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GameCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  key: const ValueKey('sound-switch'),
                  value: _soundOn,
                  onChanged: (on) {
                    setState(() => _soundOn = on);
                    // A preview, so turning sound on proves it works.
                    if (on) {
                      ref.read(soundPlayerProvider).play(GameSound.select);
                    }
                  },
                  secondary: Icon(
                    _soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: AppColors.navy,
                    size: 28,
                  ),
                  title: Text('Sound effects', style: AppText.label),
                  subtitle: Text(
                    'Pops, chimes and fanfares',
                    style: AppText.bodySmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: 'Save',
              icon: Icons.check_circle_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: AppAssets.animalNames[index],
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('avatar-$index'),
        customBorder: const CircleBorder(),
        onTap: () {
          playSoundFrom(context, GameSound.select);
          onTap();
        },
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppDurations.fast,
          padding: const EdgeInsets.all(AppSpacing.xxs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.mintDeep : Colors.transparent,
              width: 4,
            ),
          ),
          child: PlayerAvatar(index: index, size: 60),
        ),
      ),
    );
  }
}
