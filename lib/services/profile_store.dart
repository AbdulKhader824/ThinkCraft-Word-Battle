import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

/// Where the player's profile is kept. Tests use an in-memory version.
abstract interface class ProfileStore {
  PlayerProfile load();

  Future<void> save(PlayerProfile profile);
}

/// Keeps the profile on the device with shared_preferences.
///
/// It loads once at start-up, then reads from memory, so the rest of the
/// app never waits for storage.
class PrefsProfileStore implements ProfileStore {
  PrefsProfileStore(this._prefs);

  static const _nameKey = 'player_name';
  static const _avatarKey = 'player_avatar';
  static const _soundKey = 'sound_on';

  final SharedPreferencesWithCache _prefs;

  static Future<PrefsProfileStore> open() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_nameKey, _avatarKey, _soundKey},
      ),
    );
    return PrefsProfileStore(prefs);
  }

  @override
  PlayerProfile load() {
    final avatar = _prefs.getInt(_avatarKey) ?? 0;
    return PlayerProfile(
      name: _prefs.getString(_nameKey) ?? '',
      soundOn: _prefs.getBool(_soundKey) ?? true,
      avatarIndex: avatar.clamp(0, PlayerProfile.avatarCount - 1),
    );
  }

  @override
  Future<void> save(PlayerProfile profile) async {
    await _prefs.setString(_nameKey, profile.name);
    await _prefs.setInt(_avatarKey, profile.avatarIndex);
    await _prefs.setBool(_soundKey, profile.soundOn);
  }
}

/// Replaced in `main.dart` once storage has loaded.
final profileStoreProvider = Provider<ProfileStore>(
  (ref) => throw UnimplementedError('profileStoreProvider must be overridden'),
);

class ProfileNotifier extends Notifier<PlayerProfile> {
  @override
  PlayerProfile build() => ref.watch(profileStoreProvider).load();

  /// Updates the screen straight away, then saves to the device.
  Future<void> save(PlayerProfile profile) async {
    state = profile;
    await ref.read(profileStoreProvider).save(profile);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, PlayerProfile>(
  ProfileNotifier.new,
);
