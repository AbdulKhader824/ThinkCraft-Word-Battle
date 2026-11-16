import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/drawing_room.dart';
import '../game_providers.dart';
import '../nearby/nearby_platform.dart';
import 'app_drawing_service.dart';
import 'drawing_engine.dart';
import 'drawing_service.dart';

/// The Guess the Drawing service for the whole app. Tests replace it with
/// one joined to a fake network.
final drawingServiceProvider = Provider<DrawingService>((ref) {
  final service = AppDrawingService(
    engine: DrawingEngine(),
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

/// Keeps the latest drawing room as Riverpod state, so widgets using
/// `ref.watch` rebuild whenever the game changes.
class DrawingRoomNotifier extends Notifier<DrawingRoom?> {
  @override
  DrawingRoom? build() {
    final service = ref.watch(drawingServiceProvider);
    final subscription = service.roomChanges.listen((room) => state = room);
    ref.onDispose(subscription.cancel);
    return service.room;
  }
}

final drawingRoomProvider = NotifierProvider<DrawingRoomNotifier, DrawingRoom?>(
  DrawingRoomNotifier.new,
);
