import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import 'app_game_service.dart';
import 'game_service.dart';
import 'local_game_service.dart';
import 'nearby/nearby_discovery.dart';
import 'nearby/nearby_platform.dart';
import 'online/online_rooms.dart';
import 'online/relay_platform.dart';
import 'word_list_loader.dart';

/// Finds nearby rooms announced on the same Wi-Fi or hotspot. Tests
/// replace it with a fake, so they never open real network sockets.
final roomFinderProvider = Provider<RoomFinder>((ref) {
  final finder = createRoomFinder();
  ref.onDispose(finder.stop);
  return finder;
});

/// Opens and joins online rooms through the relay server, for every game.
final onlineRoomsProvider = Provider<OnlineRooms>((ref) {
  return OnlineRooms(
    openSocket: openRelaySocket,
    relay: Uri.parse(relayAddress),
  );
});

/// Something to tell the player that no screen asked for, such as an online
/// room being lost. Each one is a new object, so the same words twice are
/// still shown twice.
class RoomNotice {
  RoomNotice(this.message);

  final String message;
}

class RoomNoticeNotifier extends Notifier<RoomNotice?> {
  @override
  RoomNotice? build() => null;

  void show(String message) => state = RoomNotice(message);
}

final roomNoticeProvider = NotifierProvider<RoomNoticeNotifier, RoomNotice?>(
  RoomNoticeNotifier.new,
);

/// The game service for the whole app: practice with bots, hosting a
/// nearby room, or joining one. Tests replace it with a fake.
final gameServiceProvider = Provider<GameService>((ref) {
  final service = AppGameService(
    engine: LocalGameService(loadWords: () => loadWordList(rootBundle)),
    finder: ref.watch(roomFinderProvider),
    beacon: createRoomBeacon(),
    startServer: startNearbyServer,
    connect: connectNearby,
    findAddress: localNetworkAddress,
    online: ref.watch(onlineRoomsProvider),
    onNotice: ref.read(roomNoticeProvider.notifier).show,
  );
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
