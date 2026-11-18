import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/most_likely_room.dart';
import '../game_providers.dart';
import '../nearby/nearby_platform.dart';
import 'app_most_likely_service.dart';
import 'most_likely_engine.dart';
import 'most_likely_service.dart';

/// The Most Likely To... service for the whole app. Tests replace it with one
/// joined to a fake network.
final mostLikelyServiceProvider = Provider<MostLikelyService>((ref) {
  final service = AppMostLikelyService(
    engine: MostLikelyEngine(),
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

/// Keeps the latest Most Likely To... room as Riverpod state, so widgets using
/// `ref.watch` rebuild whenever the game changes.
class MostLikelyRoomNotifier extends Notifier<MostLikelyRoom?> {
  @override
  MostLikelyRoom? build() {
    final service = ref.watch(mostLikelyServiceProvider);
    final subscription = service.roomChanges.listen((room) => state = room);
    ref.onDispose(subscription.cancel);
    return service.room;
  }
}

final mostLikelyRoomProvider =
    NotifierProvider<MostLikelyRoomNotifier, MostLikelyRoom?>(
      MostLikelyRoomNotifier.new,
    );
