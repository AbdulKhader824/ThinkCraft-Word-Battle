import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_client.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_host.dart';
import 'package:thinkcraft_word_battle/services/online/relay.dart';
import 'package:thinkcraft_word_battle/services/online/relay_io.dart';

// Talks to a real relay server, over real WebSockets. Skipped unless
// RELAY_URL is set, for example with the relay from `server/` running:
//
//   dotnet run --project server/src/PlayPals.Relay
//   $env:RELAY_URL = 'ws://localhost:8080'; flutter test test/services/online/relay_live_test.dart

void main() {
  final address = Platform.environment['RELAY_URL'];
  final skip = address == null ? 'Set RELAY_URL to test against a relay' : null;

  test('The Impostor plays through a real relay', () async {
    final relay = Uri.parse(address!);
    final engine = ImpostorEngine(random: Random())
      ..createRoom(
        hostName: 'Sam',
        avatarIndex: 0,
        capacity: 4,
        settings: ImpostorSettings(rounds: 3, clueTurns: 1),
      );
    final code = engine.room!.code;
    final server = await RelayServer.open(
      openSocket: openRelaySocket,
      relay: relay,
      code: code,
      game: 'the_impostor',
    );
    ImpostorHost(engine: engine, server: server).start();

    final guest = ImpostorClient(
      connect: relayConnector(
        openSocket: openRelaySocket,
        relay: relay,
        code: code,
        game: 'the_impostor',
      ),
    );
    await guest.join(
      address: '',
      port: 0,
      roomCode: code,
      playerName: 'Riya',
      avatarIndex: 2,
    );
    await guest.setReady(true);
    for (
      var i = 0;
      i < 50 && !(guest.room?.players.last.isReady ?? false);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(guest.room!.players.map((p) => p.name), ['Sam', 'Riya']);
    expect(guest.room!.players.last.isReady, isTrue);

    // A wrong game is turned away with words for the player.
    await expectLater(
      RelayGuestLink.connect(
        openSocket: openRelaySocket,
        relay: relay,
        code: code,
        game: 'word_battle',
      ),
      throwsA(
        isA<JoinRefused>().having(
          (e) => e.message,
          'message',
          'That code is for a different game.',
        ),
      ),
    );

    guest.dispose();
    engine.dispose();
    await server.close();
  }, skip: skip);
}
