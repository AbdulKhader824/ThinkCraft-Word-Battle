import 'dart:async';

import '../../models/drawing_room.dart';
import '../../models/sketch.dart';
import '../game_service.dart';
import '../nearby/nearby_discovery.dart';
import '../nearby/nearby_link.dart';
import 'drawing_client.dart';
import 'drawing_engine.dart';
import 'drawing_host.dart';
import 'drawing_service.dart';

/// The Guess the Drawing service the app uses. A room this phone hosts
/// runs in [engine], with a [DrawingHost] so friends' phones can play, and
/// is announced with a [RoomBeacon] while in the lobby. Joining a friend's
/// room uses a [DrawingClient].
class AppDrawingService implements DrawingService {
  AppDrawingService({
    required this.engine,
    required this.finder,
    required this.beacon,
    required this.startServer,
    required this.connect,
    required this.findAddress,
  }) {
    _engineRoom = engine.roomChanges.listen((_) {
      if (_hosting) {
        _publish(room);
        _sketchChanged();
      }
    });
    _engineInk = engine.inkChanges.listen((_) {
      if (_hosting) _sketchChanged();
    });
  }

  final DrawingEngine engine;
  final RoomFinder finder;
  final RoomBeacon beacon;
  final Future<NearbyServer> Function() startServer;
  final NearbyConnector connect;
  final Future<String?> Function() findAddress;

  final _changes = StreamController<DrawingRoom?>.broadcast();
  final _sketchChanges = StreamController<void>.broadcast();
  late final StreamSubscription<DrawingRoom?> _engineRoom;
  late final StreamSubscription<InkEvent> _engineInk;
  StreamSubscription<DrawingRoom?>? _clientRoom;
  StreamSubscription<void>? _clientSketch;

  DrawingHost? _host;
  DrawingClient? _client;
  bool _announcing = false;
  String? _hostAddress;

  bool get _hosting => _host != null;

  @override
  DrawingRoom? get room {
    if (_hosting) return engine.roomFor(DrawingEngine.hostId);
    return _client?.room;
  }

  @override
  Stream<DrawingRoom?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId {
    if (_hosting) return engine.room == null ? null : DrawingEngine.hostId;
    return _client?.localPlayerId;
  }

  @override
  Sketch get sketch => _client?.sketch ?? engine.sketch;

  @override
  Stream<void> get sketchChanges => _sketchChanges.stream;

  @override
  String? get hostAddress => _hostAddress;

  void _publish(DrawingRoom? room) {
    if (!_changes.isClosed) _changes.add(room);
    unawaited(_announce(room));
    if (room == null) unawaited(_stop());
  }

  void _sketchChanged() {
    if (!_sketchChanges.isClosed) _sketchChanges.add(null);
  }

  @override
  Future<void> createRoom({
    required String playerName,
    required int avatarIndex,
    required int capacity,
    required DrawingSettings settings,
  }) async {
    await _leaveCurrent();
    final NearbyServer server;
    try {
      server = await startServer();
    } on Object {
      throw const JoinRefused(
        "Couldn't open a room on this network. Check Wi-Fi or your hotspot.",
      );
    }
    _host = DrawingHost(engine: engine, server: server)..start();
    _hostAddress = await findAddress();
    engine.createRoom(
      hostName: playerName,
      avatarIndex: avatarIndex,
      capacity: capacity,
      settings: settings,
    );
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
  }) async {
    final found = finder.current.where(
      (room) =>
          room.code == roomCode && room.game == NearbyRoomInfo.guessTheDrawing,
    );
    final address = hostAddress ?? found.firstOrNull?.address;
    final port = hostAddress == null
        ? found.firstOrNull?.port ?? nearbyGamePort
        : nearbyGamePort;
    if (address == null) {
      throw JoinRefused(
        'No room $roomCode found nearby. Join the same Wi-Fi or hotspot as '
        'the host, then try again.',
      );
    }

    await _leaveCurrent();
    final client = DrawingClient(connect: connect);
    _client = client;
    _clientRoom = client.roomChanges.listen((room) {
      if (identical(_client, client)) _publish(room);
    });
    _clientSketch = client.sketchChanges.listen((_) {
      if (identical(_client, client)) _sketchChanged();
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
      await _dropClient();
      rethrow;
    }
  }

  /// Announces a hosted room while it waits in the lobby for friends.
  Future<void> _announce(DrawingRoom? room) async {
    final wanted =
        _hosting &&
        room != null &&
        room.phase == DrawingPhase.lobby &&
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
        game: NearbyRoomInfo.guessTheDrawing,
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
    await _clientSketch?.cancel();
    _clientRoom = null;
    _clientSketch = null;
    client?.dispose();
  }

  Future<void> _stop() async {
    final host = _host;
    _host = null;
    _hostAddress = null;
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
    if (_hosting) engine.startGame(DrawingEngine.hostId);
  }

  @override
  Future<void> chooseWord(int index) async {
    if (_hosting) {
      engine.chooseWord(DrawingEngine.hostId, index);
    } else {
      await _client?.chooseWord(index);
    }
  }

  @override
  void draw(SketchOp op) {
    if (_hosting) {
      final room = engine.room;
      if (room != null) engine.draw(DrawingEngine.hostId, room.turnId, op);
    } else {
      _client?.draw(op);
    }
  }

  @override
  Future<void> guess(String text) async {
    if (_hosting) {
      engine.guess(DrawingEngine.hostId, text);
    } else {
      await _client?.guess(text);
    }
  }

  @override
  Future<void> nextRound() async {
    if (_hosting) {
      engine.nextRound(DrawingEngine.hostId);
    } else {
      await _client?.nextRound();
    }
  }

  @override
  Future<void> newGame() async {
    if (_hosting) engine.newGame(DrawingEngine.hostId);
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
    unawaited(_engineInk.cancel());
    engine.dispose();
    _changes.close();
    _sketchChanges.close();
  }
}
