import 'dart:async';

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
import '../../core/widgets/player_avatar.dart';
import '../../services/game_providers.dart';
import '../../services/game_service.dart';
import '../../services/nearby/nearby_discovery.dart';
import '../../services/profile_store.dart';
import '../../services/rules/room_input_rules.dart';
import 'room_form_widgets.dart';

/// Joins a friend's room: tap one of the rooms found nearby, or type its
/// code. If a room doesn't show up, the host's address can be typed in.
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
  final _addressController = TextEditingController();

  late final RoomFinder _finder = ref.read(roomFinderProvider);
  StreamSubscription<List<NearbyRoomInfo>>? _finding;
  List<NearbyRoomInfo> _rooms = const [];
  bool _showAddress = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _rooms = _finder.current;
    _finding = _finder.rooms.listen((rooms) {
      if (mounted) setState(() => _rooms = rooms);
    });
    unawaited(_finder.start());
  }

  @override
  void dispose() {
    unawaited(_finding?.cancel());
    unawaited(_finder.stop());
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Joins the room. The router then moves to the Lobby by itself, because
  /// the game's phase has changed.
  Future<void> _submit({NearbyRoomInfo? room}) async {
    if (room != null) _codeController.text = room.code;
    if (_joining || !_formKey.currentState!.validate()) return;

    final name = RoomInputRules.cleanName(_nameController.text);
    final profile = ref.read(profileProvider).copyWith(name: name);
    await ref.read(profileProvider.notifier).save(profile);
    final typedAddress = _addressController.text.trim();

    setState(() => _joining = true);
    try {
      await ref
          .read(gameServiceProvider)
          .joinRoom(
            playerName: name,
            roomCode: RoomInputRules.normalizeRoomCode(_codeController.text),
            avatarIndex: profile.avatarIndex,
            hostAddress:
                room?.address ??
                (_showAddress && typedAddress.isNotEmpty ? typedAddress : null),
          );
    } on JoinRefused catch (error) {
      if (mounted) {
        await showGameMessage(
          context,
          title: "Couldn't join",
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
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
              sticker: SvgPicture.asset(AppAssets.pencil, width: 56),
              foldedCorner: true,
              child: GameTextField(
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
            ),
            const SizedBox(height: AppSpacing.md),
            _NearbyRooms(
              rooms: _rooms,
              onJoin: _joining ? null : (room) => _submit(room: room),
            ),
            const SizedBox(height: AppSpacing.md),
            GameCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameTextField(
                    label: 'Or enter a room code',
                    hint: 'ABC234',
                    controller: _codeController,
                    validator: RoomInputRules.validateRoomCode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [RoomCodeFormatter()],
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_showAddress) ...[
                    const SizedBox(height: AppSpacing.md),
                    GameTextField(
                      key: const ValueKey('host-address'),
                      label: "Host's address",
                      hint: '192.168.43.1',
                      controller: _addressController,
                      validator: _validateAddress,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      "The host can see it in their lobby.",
                      style: AppText.bodySmall,
                    ),
                  ] else
                    TextButton(
                      onPressed: () => setState(() => _showAddress = true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size(0, AppSizes.minTapTarget),
                        textStyle: AppText.bodySmall,
                      ),
                      child: const Text("Can't see the room? Type the address"),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GameButton(
              label: _joining ? 'Joining...' : 'Join Room',
              icon: Icons.login_rounded,
              style: GameButtonStyle.sunshine,
              onPressed: _joining ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  static String? _validateAddress(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parts = text.split('.');
    final looksRight =
        parts.length == 4 &&
        parts.every((part) {
          final number = int.tryParse(part);
          return number != null && number >= 0 && number <= 255;
        });
    return looksRight ? null : 'That address should look like 192.168.43.1';
  }
}

/// The rooms found on this Wi-Fi or hotspot, each one tap to join.
class _NearbyRooms extends StatelessWidget {
  const _NearbyRooms({required this.rooms, required this.onJoin});

  final List<NearbyRoomInfo> rooms;
  final ValueChanged<NearbyRoomInfo>? onJoin;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      color: AppColors.sky,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_rounded, color: AppColors.navy),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Rooms nearby', style: AppText.label)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (rooms.isEmpty)
            Text(
              'Looking for rooms... Join the same Wi-Fi or hotspot as the '
              'host.',
              style: AppText.bodySmall,
            )
          else
            for (final room in rooms) ...[
              _NearbyRoomTile(
                key: ValueKey('nearby-${room.code}'),
                room: room,
                onTap: onJoin == null ? null : () => onJoin!(room),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _NearbyRoomTile extends StatelessWidget {
  const _NearbyRoomTile({super.key, required this.room, required this.onTap});

  final NearbyRoomInfo room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    final capacity = room.capacity;
    final players = room.isFull
        ? 'Full'
        : capacity != null
        ? '${room.playerCount} of $capacity players'
        : room.playerCount == 1
        ? '1 player'
        : '${room.playerCount} players';

    return Semantics(
      button: true,
      label: "Join ${room.hostName}'s room, ${room.code}, $players",
      excludeSemantics: true,
      child: Material(
        color: AppColors.cream,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              children: [
                PlayerAvatar(index: room.hostAvatar, size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${room.hostName}'s room",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label,
                      ),
                      Text('${room.code} · $players', style: AppText.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.login_rounded, color: AppColors.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
