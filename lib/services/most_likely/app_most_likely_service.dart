import 'dart:async';

import '../../models/most_likely_room.dart';
import '../game_service.dart';
import '../nearby/nearby_discovery.dart';
import '../nearby/nearby_link.dart';
import '../online/online_rooms.dart';
import '../online/relay.dart';
import 'most_likely_client.dart';
import 'most_likely_engine.dart';
import 'most_likely_host.dart';
import 'most_likely_service.dart';

/// The Most Likely To... service the app uses. A room this phone hosts runs in
/// [engine], with a [MostLikelyHost] so friends' phones can play, and is
/// announced with a [RoomBeacon] while in the lobby. Joining a friend's
/// room uses a [MostLikelyClient].
class AppMostLikelyService implements MostLikelyService {
  AppMostLikelyService({
    required this.engine,
    required this.finder,
    required this.beacon,
    required this.startServer,
    required this.connect,
    required this.findAddress,
    this.online,
    this.onNotice,
  }) {
    _engineRoom = engine.roomChanges.listen((_) {
      if (_hosting) _publish(room);
    });
  }

  final MostLikelyEngine engine;
  final RoomFinder finder;
  final RoomBeacon beacon;
  final Future<NearbyServer> Function() startServer;
  final NearbyConnector connect;
  final Future<String?> Function() findAddress;

  /// Opens and joins online rooms through the relay. Null where they
  /// aren't offered.
  final OnlineRooms? online;

  /// Tells the player something happened outside the screens' control,
  /// such as an online room being lost.
  final void Function(String message)? onNotice;

  final _changes = StreamController<MostLikelyRoom?>.broadcast();
  late final StreamSubscription<MostLikelyRoom?> _engineRoom;
  StreamSubscription<MostLikelyRoom?>? _clientRoom;

  MostLikelyHost? _host;
  MostLikelyClient? _client;
  bool _announcing = false;
  String? _hostAddress;
  bool _isOnline = false;

  bool get _hosting => _host != null;

  @override
  MostLikelyRoom? get room {
    if (_hosting) return engine.roomFor(MostLikelyEngine.hostId);
    return _client?.room;
  }

  @override
  Stream<MostLikelyRoom?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId {
    if (_hosting) return engine.room == null ? null : MostLikelyEngine.hostId;
    return _client?.localPlayerId;
  }

  @override
  String? get hostAddress => _hostAddress;

  @override
  bool get isOnline => _isOnline;

  OnlineRooms get _online {
    final online = this.online;
    if (online == null) {
      throw const JoinRefused('Online rooms need the phone app.');
    }
    return online;
  }

  void _publish(MostLikelyRoom? room) {
    if (!_changes.isClosed) _changes.add(room);
    unawaited(_announce(room));
    if (room == null) unawaited(_stop());
  }

  @override
  Future<void> createRoom({
    required String playerName,
    required int avatarIndex,
    required int capacity,
    required MostLikelySettings settings,
    bool online = false,
  }) async {
    await _leaveCurrent();
    if (online) {
      final server = await _online.host(game: NearbyRoomInfo.mostLikelyTo);
      _host = MostLikelyHost(engine: engine, server: server)..start();
      _isOnline = true;
      unawaited(server.lost.then((_) => _lost(server)));
      engine.createRoom(
        hostName: playerName,
        avatarIndex: avatarIndex,
        capacity: capacity,
        settings: settings,
        code: server.code,
      );
      return;
    }

    final NearbyServer server;
    try {
      server = await startServer();
    } on Object {
      throw const JoinRefused(
        "Couldn't open a room on this network. Check Wi-Fi or your hotspot.",
      );
    }
    _host = MostLikelyHost(engine: engine, server: server)..start();
    _hostAddress = await findAddress();
    engine.createRoom(
      hostName: playerName,
      avatarIndex: avatarIndex,
      capacity: capacity,
      settings: settings,
    );
  }

  /// The online room's connection is gone for good: the room closes.
  Future<void> _lost(RelayServer server) async {
    if (!identical(_host?.server, server)) return;
    onNotice?.call(onlineRoomLost);
    await leaveRoom();
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  }) async {
    final found = finder.current.where(
      (room) =>
          room.code == roomCode && room.game == NearbyRoomInfo.mostLikelyTo,
    );
    final address = online ? '' : hostAddress ?? found.firstOrNull?.address;
    final port = hostAddress == null
        ? found.firstOrNull?.port ?? nearbyGamePort
        : nearbyGamePort;
    if (address == null) {
      throw JoinRefused(
        'No room $roomCode found nearby. Join the same Wi-Fi or hotspot as '
        'the host, then try again.',
      );
    }

    final link = online
        ? _online.guest(code: roomCode, game: NearbyRoomInfo.mostLikelyTo)
        : connect;

    await _leaveCurrent();
    final client = MostLikelyClient(connect: link);
    _client = client;
    _isOnline = online;
    _clientRoom = client.roomChanges.listen((room) {
      if (identical(_client, client)) _publish(room);
    });
    try {
      await client.join(
        address: address,
        port: port,
        roomCode: roomCode,
        playerName: playerName,
        avatarIndex: avatarIndex,
      );
    } on Object {
      _isOnline = false;
      await _dropClient();
      rethrow;
    }
  }

  /// Announces a hosted room while it waits in the lobby for friends.
  Future<void> _announce(MostLikelyRoom? room) async {
    final wanted =
        _hosting &&
        !_isOnline &&
        room != null &&
        room.phase == MostLikelyPhase.lobby &&
        room.emptySeats > 0;
    if (wanted == _announcing) return;
    _announcing = wanted;
    if (!wanted) {
      await beacon.stop();
      return;
    }
    await beacon.start(() {
      final current = engine.room!;
      final host = current.host;
      return NearbyRoomInfo(
        code: current.code,
        hostName: host.name,
        hostAvatar: host.avatarIndex,
        playerCount: current.players.length,
        capacity: current.capacity,
        address: _hostAddress ?? '',
        port: _host?.server.port ?? nearbyGamePort,
        game: NearbyRoomInfo.mostLikelyTo,
      );
    });
  }

  Future<void> _leaveCurrent() async {
    if (_hosting && engine.room != null) {
      engine.close();
      _publish(null);
    }
    if (_client?.room != null) {
      await _client!.leaveRoom();
      _publish(null);
    }
    await _stop();
  }

  Future<void> _dropClient() async {
    final client = _client;
    _client = null;
    await _clientRoom?.cancel();
    _clientRoom = null;
    client?.dispose();
  }

  Future<void> _stop() async {
    final host = _host;
    _host = null;
    _hostAddress = null;
    _isOnline = false;
    if (_announcing) {
      _announcing = false;
      await beacon.stop();
    }
    await host?.stop();
    await _dropClient();
  }

  @override
  Future<void> setReady(bool isReady) async {
    if (_hosting) return;
    await _client?.setReady(isReady);
  }

  @override
  Future<void> startGame() async {
    if (_hosting) engine.startGame(MostLikelyEngine.hostId);
  }

  @override
  Future<void> vote(String playerId) async {
    if (_hosting) {
      engine.vote(MostLikelyEngine.hostId, playerId);
    } else {
      await _client?.vote(playerId);
    }
  }

  @override
  Future<void> nextRound() async {
    if (_hosting) {
      engine.nextRound(MostLikelyEngine.hostId);
    } else {
      await _client?.nextRound();
    }
  }

  @override
  Future<void> newGame() async {
    if (_hosting) engine.newGame(MostLikelyEngine.hostId);
  }

  @override
  Future<void> refresh() async {
    if (_hosting) engine.refresh();
  }

  @override
  Future<void> leaveRoom() async {
    if (_hosting) {
      // The host leaving closes the room for everyone. The screens hear
      // now, rather than from the engine's later message, which arrives
      // after hosting has stopped and would be ignored.
      engine.close();
      _publish(null);
    } else {
      final client = _client;
      if (client != null) {
        await client.leaveRoom();
        _publish(null);
      }
    }
    await _stop();
  }

  @override
  void dispose() {
    unawaited(_stop());
    unawaited(_engineRoom.cancel());
    engine.dispose();
    _changes.close();
  }
}
