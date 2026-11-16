import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/drawing_room.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/services/app_game_service.dart';
import 'package:thinkcraft_word_battle/services/drawing/app_drawing_service.dart';
import 'package:thinkcraft_word_battle/services/drawing/drawing_engine.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/app_impostor_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/online/online_rooms.dart';

import '../../fakes.dart';
import '../../memory_relay.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

final _relayUri = Uri.parse('wss://relay.example');

/// Every phone reaches the same pretend relay, and no Wi-Fi at all.
OnlineRooms _online(MemoryRelay relay, int seed) =>
    OnlineRooms(openSocket: relay.open, relay: _relayUri, random: Random(seed));

Future<Never> _noWifi() async => throw StateError('No Wi-Fi in these tests');

void main() {
  late MemoryRelay relay;

  setUp(() => relay = MemoryRelay());

  group('Word Battle online', () {
    final notices = <String>[];
    final beacon = FakeRoomBeacon();

    AppGameService phone(int seed, {bool withOnline = true}) => AppGameService(
      engine: LocalGameService(random: Random(seed)),
      finder: FakeRoomFinder(),
      beacon: beacon,
      startServer: _noWifi,
      connect: (_, _) => _noWifi(),
      findAddress: () async => null,
      online: withOnline ? _online(relay, seed) : null,
      onNotice: notices.add,
    );

    setUp(notices.clear);

    test('a friend joins by code, from anywhere', () async {
      final host = phone(1);
      await host.createRoom(
        playerName: 'Sam',
        playerCount: 4,
        mode: RoomMode.online,
      );
      final code = host.room!.code;
      expect(relay.hasRoom(code), isTrue);
      expect(host.room!.mode, RoomMode.online);
      expect(host.room!.players, hasLength(1));
      // Online rooms aren't announced on the Wi-Fi, and have no address.
      expect(beacon.announcing, isFalse);
      expect(host.hostAddress, isNull);

      final guest = phone(2);
      await guest.joinRoom(playerName: 'Riya', roomCode: code, online: true);
      await _settle();
      expect(guest.room!.mode, RoomMode.online);
      expect(host.room!.players.map((p) => p.name), ['Sam', 'Riya']);
      expect(relay.opened.last.queryParameters['game'], 'word_battle');
    });

    test('a wrong code says so', () async {
      await expectLater(
        phone(2).joinRoom(playerName: 'Riya', roomCode: 'ZZZ222', online: true),
        throwsA(
          isA<JoinRefused>().having(
            (e) => e.message,
            'message',
            contains("There's no room with that code"),
          ),
        ),
      );
    });

    test('without internet, the host is told', () async {
      relay.reachable = false;
      await expectLater(
        phone(
          1,
        ).createRoom(playerName: 'Sam', playerCount: 4, mode: RoomMode.online),
        throwsA(
          isA<JoinRefused>().having(
            (e) => e.message,
            'message',
            contains("Couldn't reach the online server"),
          ),
        ),
      );
    });

    test('where online rooms are not offered, it explains', () async {
      await expectLater(
        phone(
          1,
          withOnline: false,
        ).createRoom(playerName: 'Sam', playerCount: 4, mode: RoomMode.online),
        throwsA(isA<JoinRefused>()),
      );
    });

    test('a lost room closes, and the host is told why', () async {
      final host = phone(1);
      await host.createRoom(
        playerName: 'Sam',
        playerCount: 4,
        mode: RoomMode.online,
      );
      final code = host.room!.code;

      relay.hostSocket(code)!.drop();
      relay.hostTimesOut(code);
      // The host tries to get back after 2 seconds, and hears it's gone.
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(host.room, isNull);
      expect(notices, [onlineRoomLost]);
    });
  });

  test('The Impostor: an online room is joined by code', () async {
    final beacon = FakeRoomBeacon();
    AppImpostorService phone(int seed) => AppImpostorService(
      engine: ImpostorEngine(random: Random(seed)),
      finder: FakeRoomFinder(),
      beacon: beacon,
      startServer: _noWifi,
      connect: (_, _) => _noWifi(),
      findAddress: () async => null,
      online: _online(relay, seed),
    );

    final host = phone(1);
    await host.createRoom(
      playerName: 'Sam',
      avatarIndex: 0,
      capacity: 4,
      settings: ImpostorSettings(),
      online: true,
    );
    expect(host.isOnline, isTrue);
    expect(beacon.announcing, isFalse);
    final code = host.room!.code;
    expect(relay.hasRoom(code), isTrue);

    final guest = phone(2);
    await guest.joinRoom(playerName: 'Riya', roomCode: code, online: true);
    await _settle();
    expect(guest.isOnline, isTrue);
    expect(guest.room!.players.map((p) => p.name), ['Sam', 'Riya']);
    expect(relay.opened.last.queryParameters['game'], 'the_impostor');

    await guest.leaveRoom();
    expect(guest.isOnline, isFalse);
    await host.leaveRoom();
    await _settle();
    expect(host.isOnline, isFalse);
    // The host leaving closes the room on the relay too.
    expect(relay.hasRoom(code), isFalse);
  });

  test('Guess the Drawing: an online room is joined by code', () async {
    AppDrawingService phone(int seed) => AppDrawingService(
      engine: DrawingEngine(random: Random(seed)),
      finder: FakeRoomFinder(),
      beacon: FakeRoomBeacon(),
      startServer: _noWifi,
      connect: (_, _) => _noWifi(),
      findAddress: () async => null,
      online: _online(relay, seed),
    );

    final host = phone(1);
    await host.createRoom(
      playerName: 'Sam',
      avatarIndex: 0,
      capacity: 4,
      settings: DrawingSettings(),
      online: true,
    );
    final code = host.room!.code;

    final guest = phone(2);
    await guest.joinRoom(playerName: 'Riya', roomCode: code, online: true);
    await _settle();
    expect(guest.isOnline, isTrue);
    expect(guest.room!.players.map((p) => p.name), ['Sam', 'Riya']);
    expect(relay.opened.last.queryParameters['game'], 'guess_the_drawing');
  });

  test('a code already in use is swapped for another', () async {
    final first = _online(relay, 7);
    final taken = await first.host(game: 'the_impostor');
    // The same seed picks the same first code, which is taken.
    final second = await _online(relay, 7).host(game: 'the_impostor');
    expect(second.code, isNot(taken.code));
  });
}
