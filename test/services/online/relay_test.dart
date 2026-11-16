import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/impostor_room.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_client.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_host.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_link.dart';
import 'package:thinkcraft_word_battle/services/online/relay.dart';

import '../../memory_relay.dart';

final _relayUri = Uri.parse('wss://relay.example');
const _code = 'ABC234';
const _game = 'the_impostor';

/// Lets the pretend relay's messages arrive.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late MemoryRelay relay;

  setUp(() => relay = MemoryRelay());

  Future<RelayServer> openRoom({String code = _code}) => RelayServer.open(
    openSocket: relay.open,
    relay: _relayUri,
    code: code,
    game: _game,
    resumeGap: const Duration(milliseconds: 10),
  );

  Future<NearbyLink> join({String code = _code, String game = _game}) =>
      relayConnector(
        openSocket: relay.open,
        relay: _relayUri,
        code: code,
        game: game,
      )('', 0);

  /// The next friend to arrive at the host's phone.
  Future<NearbyLink> nextGuest(RelayServer server) => server.links.first;

  test('phones open the relay addresses for their room', () async {
    await openRoom();
    await join();
    expect(relay.opened.map((uri) => uri.toString()), [
      'wss://relay.example/host?code=ABC234&game=the_impostor',
      'wss://relay.example/join?code=ABC234&game=the_impostor',
    ]);
  });

  test('a friend and the host pass messages both ways', () async {
    final server = await openRoom();
    final arriving = nextGuest(server);
    final guest = await join();
    final atHost = await arriving;

    final toHost = <Map<String, Object?>>[];
    final toGuest = <Map<String, Object?>>[];
    atHost.messages.listen(toHost.add);
    guest.messages.listen(toGuest.add);

    guest.send({'t': 'join', 'name': 'Riya', 'note': 'a:b:c'});
    await _settle();
    expect(toHost, [
      {'t': 'join', 'name': 'Riya', 'note': 'a:b:c'},
    ]);

    atHost.send({'t': 'welcome', 'id': 'p1'});
    await _settle();
    expect(toGuest, [
      {'t': 'welcome', 'id': 'p1'},
    ]);
  });

  test("each friend gets only their own messages", () async {
    final server = await openRoom();
    final atHost = <NearbyLink>[];
    server.links.listen(atHost.add);
    final riya = await join();
    final ali = await join();
    await _settle();
    expect(atHost, hasLength(2));

    final riyaGot = <Object?>[];
    final aliGot = <Object?>[];
    riya.messages.listen((m) => riyaGot.add(m['to']));
    ali.messages.listen((m) => aliGot.add(m['to']));
    atHost[1].send({'to': 'ali'});
    atHost[0].send({'to': 'riya'});
    await _settle();
    expect(riyaGot, ['riya']);
    expect(aliGot, ['ali']);
  });

  test('a friend leaving ends their link on the host phone', () async {
    final server = await openRoom();
    final arriving = nextGuest(server);
    final guest = await join();
    final atHost = await arriving;

    await guest.close();
    await atHost.done.timeout(const Duration(seconds: 1));
  });

  test('the host closing a link removes that friend', () async {
    final server = await openRoom();
    final arriving = nextGuest(server);
    final guest = await join();
    final atHost = await arriving;

    await atHost.close();
    await guest.done.timeout(const Duration(seconds: 1));
    expect(relay.guestCount(_code), 0);
  });

  test('the host leaving closes the room for everyone', () async {
    final server = await openRoom();
    final guest = await join();
    await server.close();

    await guest.done.timeout(const Duration(seconds: 1));
    expect(relay.hasRoom(_code), isFalse);
  });

  group('turned away', () {
    Future<String> refusal(Future<Object?> joining) async {
      try {
        await joining;
      } on JoinRefused catch (error) {
        return error.message;
      }
      fail('Expected to be turned away');
    }

    test('with no room for that code', () async {
      expect(
        await refusal(join()),
        "There's no room with that code. Check it and try again.",
      );
    });

    test('with a code for another game', () async {
      await openRoom();
      expect(
        await refusal(join(game: 'word_battle')),
        'That code is for a different game.',
      );
    });

    test('without internet', () async {
      relay.reachable = false;
      expect(
        await refusal(join()),
        "Couldn't reach the online server. Check your internet and try again.",
      );
    });

    test('a host whose code is taken is told so', () async {
      await openRoom();
      await expectLater(
        openRoom(),
        throwsA(isA<RelayRefused>().having((r) => r.codeTaken, 'taken', true)),
      );
    });
  });

  group('the host phone loses its connection', () {
    test('it comes back, and friends stay in the room', () async {
      final server = await openRoom();
      final arriving = nextGuest(server);
      final guest = await join();
      final atHost = await arriving;
      final toHost = <Object?>[];
      atHost.messages.listen((m) => toHost.add(m['n']));

      relay.hostSocket(_code)!.drop();
      await _settle();
      expect(server.isConnected, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(server.isConnected, isTrue);
      expect(relay.opened.last.queryParameters['key'], 'key1');
      guest.send({'n': 1});
      await _settle();
      expect(toHost, [1]);
      final toGuest = <Object?>[];
      guest.messages.listen((m) => toGuest.add(m['n']));
      atHost.send({'n': 2});
      await _settle();
      expect(toGuest, [2]);
    });

    test('a friend who left meanwhile is gone when it comes back', () async {
      final server = await openRoom();
      final atHost = <NearbyLink>[];
      server.links.listen(atHost.add);
      final riya = await join();
      await join();
      await _settle();

      relay.hostSocket(_code)!.drop();
      await riya.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(server.isConnected, isTrue);
      await atHost[0].done.timeout(const Duration(seconds: 1));
      expect(relay.guestCount(_code), 1);
    });

    test('if the room has gone, every friend is let go', () async {
      final server = await openRoom();
      final arriving = nextGuest(server);
      await join();
      final atHost = await arriving;

      relay.hostSocket(_code)!.drop();
      relay.hostTimesOut(_code);
      await server.lost.timeout(const Duration(seconds: 1));
      await atHost.done.timeout(const Duration(seconds: 1));
    });

    test('it gives up after a few tries without internet', () async {
      final server = await openRoom();
      relay
        ..hostSocket(_code)!.drop()
        ..reachable = false;
      await server.lost.timeout(const Duration(seconds: 1));
    });
  });

  test(
    'The Impostor plays through the relay, and a friend can rejoin',
    () async {
      final engine = ImpostorEngine(random: Random(5))
        ..createRoom(
          hostName: 'Sam',
          avatarIndex: 0,
          capacity: 4,
          settings: ImpostorSettings(rounds: 3, clueTurns: 1),
        );
      final server = await openRoom(code: engine.room!.code);
      ImpostorHost(engine: engine, server: server).start();

      final guest = ImpostorClient(
        connect: relayConnector(
          openSocket: relay.open,
          relay: _relayUri,
          code: engine.room!.code,
          game: _game,
        ),
        reconnectGap: const Duration(milliseconds: 10),
      );
      await guest.join(
        address: '',
        port: 0,
        roomCode: engine.room!.code,
        playerName: 'Riya',
        avatarIndex: 2,
      );
      await guest.setReady(true);
      await _settle();
      final id = guest.localPlayerId!;
      expect(engine.room!.players.map((p) => p.name), ['Sam', 'Riya']);
      expect(
        engine.room!.players.firstWhere((p) => p.id == id).isReady,
        isTrue,
      );
      expect(guest.room!.players, hasLength(2));

      // Riya's signal drops mid-game; she comes back as the same player.
      final third = engine.addPlayer(name: 'Ali', avatarIndex: 3);
      engine
        ..setReady(third, true)
        ..startGame(ImpostorEngine.hostId);
      await _settle();
      relay.guestSockets.single.drop();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(engine.room!.awayIds, isNot(contains(id)));
      expect(guest.localPlayerId, id);
      expect(guest.room!.phase, ImpostorPhase.word);

      guest.dispose();
      engine.dispose();
      await server.close();
    },
  );
}
