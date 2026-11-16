import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/impostor_room.dart';
import '../game_providers.dart';
import '../nearby/nearby_platform.dart';
import 'app_impostor_service.dart';
import 'impostor_engine.dart';
import 'impostor_service.dart';

/// The Impostor service for the whole app. Tests replace it with one
/// joined to a fake network.
final impostorServiceProvider = Provider<ImpostorService>((ref) {
  final service = AppImpostorService(
    engine: ImpostorEngine(),
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

/// Keeps the latest Impostor room as Riverpod state, so widgets using
/// `ref.watch` rebuild whenever the game changes.
class ImpostorRoomNotifier extends Notifier<ImpostorRoom?> {
  @override
  ImpostorRoom? build() {
    final service = ref.watch(impostorServiceProvider);
    final subscription = service.roomChanges.listen((room) => state = room);
    ref.onDispose(subscription.cancel);
    return service.room;
  }
}

final impostorRoomProvider =
    NotifierProvider<ImpostorRoomNotifier, ImpostorRoom?>(
      ImpostorRoomNotifier.new,
    );
