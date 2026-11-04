import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_store.dart';

/// The game's sound effects. Each one is a short WAV file in
/// `assets/sounds/`, made by `tool/generate_sounds.py`.
enum GameSound {
  tap,
  select,
  ready,
  reveal,
  tick,
  lock,
  valid,
  invalid,
  results,
  win;

  /// The path audioplayers expects, which is relative to `assets/`.
  String get asset => 'sounds/$name.wav';
}

/// Plays sound effects. Tests use a fake that records what was played.
abstract interface class SoundPlayer {
  void play(GameSound sound);

  void dispose();
}

/// Plays through audioplayers, with each sound loaded once and kept ready
/// so taps sound instantly.
class AudioSoundPlayer implements SoundPlayer {
  AudioSoundPlayer() {
    // Play alongside music or other apps, rather than pausing them.
    _context = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
        .build();
    unawaited(_quietly(() => AudioPlayer.global.setAudioContext(_context)));
  }

  /// Up to this many copies of one sound can overlap, as with fast ticks.
  static const _maxOverlap = 3;

  late final AudioContext _context;
  final _pools = <GameSound, Future<AudioPool>>{};

  @override
  void play(GameSound sound) {
    final pool = _pools.putIfAbsent(
      sound,
      () => AudioPool.create(
        source: AssetSource(sound.asset),
        maxPlayers: _maxOverlap,
        playerMode: PlayerMode.lowLatency,
        audioContext: _context,
      ),
    );
    unawaited(_quietly(() async => (await pool).start()));
  }

  /// A sound that fails to play, such as before a web page has been
  /// tapped, must never break the game.
  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Sound skipped: $error');
    }
  }

  @override
  void dispose() {
    for (final pool in _pools.values) {
      unawaited(_quietly(() async => (await pool).dispose()));
    }
    _pools.clear();
  }
}

final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = AudioSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Plays [sound] if the player has sound turned on.
void playSound(WidgetRef ref, GameSound sound) {
  if (ref.read(profileProvider).soundOn) {
    ref.read(soundPlayerProvider).play(sound);
  }
}

/// The same as [playSound], for widgets that only have a [BuildContext].
/// Does nothing outside the app, such as in a widget shown on its own.
void playSoundFrom(BuildContext context, GameSound sound) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    return;
  }
  if (container.read(profileProvider).soundOn) {
    container.read(soundPlayerProvider).play(sound);
  }
}
