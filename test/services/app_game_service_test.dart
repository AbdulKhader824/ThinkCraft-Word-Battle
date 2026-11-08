import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/services/app_game_service.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';

import '../fakes.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// One phone's game service, joined to a shared pretend network.
class _Phone {
  _Phone(this.network, {FakeRoomFinder? finder})
    : finder = finder ?? FakeRoomFinder() {
    service = AppGameService(
      engine: LocalGameService(random: Random(2)),
      finder: this.finder,
      beacon: beacon,
      startServer: () async => network,
      connect: network.connect,
      findAddress: () async => '192.168.43.1',
    );
  }

  final MemoryServer network;
  final FakeRoomFinder finder;
  final beacon = FakeRoomBeacon();
  late final AppGameService service;

  /// What another phone would hear from this one's announcements.
  NearbyRoomInfo heard() {
    final info = beacon.describe!();
    return NearbyRoomInfo(
      code: info.code,
      hostName: info.hostName,
      hostAvatar: info.hostAvatar,
      playerCount: info.playerCount,
      address: '192.168.43.1',
      port: info.port,
    );
  }
}

void main() {
  test('practice rooms run on the phone, with bots', () async {
    final phone = _Phone(MemoryServer());

    await phone.service.createRoom(playerName: 'Sam', playerCount: 4);

    expect(phone.service.room!.mode, RoomMode.practice);
    expect(phone.service.room!.players, hasLength(4));
    expect(phone.beacon.announcing, isFalse);
    expect(phone.service.hostAddress, isNull);
  });

  test('hosting a nearby room announces it and shows the address', () async {
    final host = _Phone(MemoryServer());

    await host.service.createRoom(
      playerName: 'Sam',
      playerCount: 4,
      mode: RoomMode.nearby,
    );
    await _settle();

    expect(host.service.room!.players, hasLength(1));
    expect(host.beacon.announcing, isTrue);
    expect(host.heard().hostName, 'Sam');
    expect(host.service.hostAddress, '192.168.43.1');
  });

  test('a friend finds the room and joins it', () async {
    final network = MemoryServer();
    final host = _Phone(network);
    final guest = _Phone(network);
    await host.service.createRoom(
      playerName: 'Sam',
      playerCount: 4,
      mode: RoomMode.nearby,
    );
    await _settle();
    guest.finder.show([host.heard()]);

    await guest.service.joinRoom(
      playerName: 'Luna',
      roomCode: host.service.room!.code,
    );
    await _settle();

    expect(guest.service.room!.players.map((p) => p.name), ['Sam', 'Luna']);
    expect(host.service.room!.players, hasLength(2));
    expect(host.heard().playerCount, 2);
  });

  test('a code that is not nearby explains what to do', () async {
    final guest = _Phone(MemoryServer());

    await expectLater(
      guest.service.joinRoom(playerName: 'Luna', roomCode: 'K7PQ2M'),
      throwsA(
        isA<JoinRefused>().having(
          (error) => error.message,
          'message',
          contains('same Wi-Fi'),
        ),
      ),
    );
  });

  test('the room stops announcing once the game starts', () async {
    final network = MemoryServer();
    final host = _Phone(network);
    final guest = _Phone(network);
    await host.service.createRoom(
      playerName: 'Sam',
      playerCount: 4,
      mode: RoomMode.nearby,
    );
    await _settle();
    guest.finder.show([host.heard()]);
    await guest.service.joinRoom(
      playerName: 'Luna',
      roomCode: host.service.room!.code,
    );
    await _settle();

    await guest.service.setReady(true);
    await _settle();
    await host.service.startRound();
    await _settle();

    expect(host.beacon.announcing, isFalse);
    expect(guest.service.room!.phase, GamePhase.letterSelection);
  });

  test(
    'when the host leaves, the friend goes home and can play again',
    () async {
      final network = MemoryServer();
      final host = _Phone(network);
      final guest = _Phone(network);
      await host.service.createRoom(
        playerName: 'Sam',
        playerCount: 4,
        mode: RoomMode.nearby,
      );
      await _settle();
      guest.finder.show([host.heard()]);
      await guest.service.joinRoom(
        playerName: 'Luna',
        roomCode: host.service.room!.code,
      );
      await _settle();

      await host.service.leaveRoom();
      await _settle();

      expect(guest.service.room, isNull);
      expect(host.beacon.announcing, isFalse);

      // The guest's phone is free for a practice game.
      await guest.service.createRoom(playerName: 'Luna', playerCount: 3);
      expect(guest.service.room!.mode, RoomMode.practice);
    },
  );

  test('a friend who leaves is taken out of the lobby', () async {
    final network = MemoryServer();
    final host = _Phone(network);
    final guest = _Phone(network);
    await host.service.createRoom(
      playerName: 'Sam',
      playerCount: 4,
      mode: RoomMode.nearby,
    );
    await _settle();
    guest.finder.show([host.heard()]);
    await guest.service.joinRoom(
      playerName: 'Luna',
      roomCode: host.service.room!.code,
    );
    await _settle();

    await guest.service.leaveRoom();
    await _settle();

    expect(guest.service.room, isNull);
    expect(host.service.room!.players, hasLength(1));
  });
}
