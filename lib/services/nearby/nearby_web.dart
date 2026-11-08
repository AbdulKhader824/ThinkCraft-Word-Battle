import 'nearby_discovery.dart';
import 'nearby_link.dart';

// Browsers can't host games or find rooms on the local network, so the web
// version offers practice only. Phones use nearby_io.dart.

Future<NearbyServer> startNearbyServer() {
  throw UnsupportedError('Nearby rooms need the phone app.');
}

Future<NearbyLink> connectNearby(String address, int port) {
  throw UnsupportedError('Nearby rooms need the phone app.');
}

RoomFinder createRoomFinder() => NoRoomFinder();

RoomBeacon createRoomBeacon() => _NoBeacon();

Future<String?> localNetworkAddress() async => null;

class _NoBeacon implements RoomBeacon {
  @override
  Future<void> start(NearbyRoomInfo Function() describe) async {}

  @override
  Future<void> stop() async {}
}
