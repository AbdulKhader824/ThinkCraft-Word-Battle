import 'dart:math';

import '../game_service.dart';
import '../nearby/nearby_link.dart';
import '../rules/room_input_rules.dart';
import 'relay.dart';

/// The relay server online rooms use. Builds can point elsewhere, such as
/// a relay running on this computer for the emulator:
/// `flutter run --dart-define=RELAY_URL=ws://10.0.2.2:8080`.
const relayAddress = String.fromEnvironment(
  'RELAY_URL',
  defaultValue: 'wss://playpals-relay.onrender.com',
);

/// Opens and joins online rooms through the relay, for every game.
class OnlineRooms {
  OnlineRooms({required this.openSocket, required this.relay, Random? random})
    : _random = random ?? Random.secure();

  final RelayOpener openSocket;
  final Uri relay;
  final Random _random;

  /// Opens a room for [game] with a new code; the room's code is the
  /// server's [RelayServer.code]. Throws [JoinRefused] with words for the
  /// player if the relay can't be reached.
  Future<RelayServer> host({required String game}) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await RelayServer.open(
          openSocket: openSocket,
          relay: relay,
          code: _newCode(),
          game: game,
        );
      } on RelayRefused catch (refusal) {
        // Someone else has that code: pick another.
        if (refusal.codeTaken && attempt < 5) continue;
        throw JoinRefused(refusal.message);
      }
    }
  }

  /// Connects a friend's phone to the online room with [code].
  NearbyConnector guest({required String code, required String game}) {
    return relayConnector(
      openSocket: openSocket,
      relay: relay,
      code: code,
      game: game,
    );
  }

  String _newCode() {
    const characters = RoomInputRules.roomCodeCharacters;
    return List.generate(
      RoomInputRules.roomCodeLength,
      (_) => characters[_random.nextInt(characters.length)],
    ).join();
  }
}

/// What the host is told when the online room is lost.
const onlineRoomLost =
    'The connection to the online server was lost, so the room closed.';
