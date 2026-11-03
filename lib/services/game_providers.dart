import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import 'game_service.dart';
import 'local_game_service.dart';

/// The game service for the whole app. This is the one line to change when
/// a real online service exists, and tests replace it with a fake.
final gameServiceProvider = Provider<GameService>((ref) {
  final service = LocalGameService();
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the latest room as Riverpod state, so widgets using `ref.watch`
/// rebuild whenever the game changes.
class GameRoomNotifier extends Notifier<Room?> {
  @override
  Room? build() {
    final service = ref.watch(gameServiceProvider);
    final subscription = service.roomChanges.listen((room) => state = room);
    ref.onDispose(subscription.cancel);
    return service.room;
  }
}

final gameRoomProvider = NotifierProvider<GameRoomNotifier, Room?>(
  GameRoomNotifier.new,
);
