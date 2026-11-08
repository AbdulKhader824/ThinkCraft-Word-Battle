import 'dart:async';

import '../models/category.dart';
import '../models/game_phase.dart';
import '../models/game_settings.dart';
import '../models/room.dart';
import '../models/vote.dart';
import 'game_service.dart';
import 'local_game_service.dart';
import 'nearby/nearby_client.dart';
import 'nearby/nearby_discovery.dart';
import 'nearby/nearby_host.dart';
import 'nearby/nearby_link.dart';

/// The game service the app uses. It hands each game to the right place:
///
/// - **Practice** and rooms this phone **hosts** run in [engine], here on
///   the phone. A hosted room also opens a [NearbyHost], so friends' phones
///   can play in it, and announces itself with a [RoomBeacon].
/// - Joining a friend's room uses a [NearbyClientService], which talks to
///   the host's phone.
///
/// Screens only see [GameService], so none of this reaches them.
class AppGameService implements GameService {
  AppGameService({
    required this.engine,
    required this.finder,
    required this.beacon,
    required this.startServer,
    required this.connect,
    required this.findAddress,
  }) {
    _engineChanges = engine.roomChanges.listen((room) {
      if (identical(_active, engine)) _onRoom(room);
    });
  }

  final LocalGameService engine;
  final RoomFinder finder;
  final RoomBeacon beacon;
  final Future<NearbyServer> Function() startServer;
  final NearbyConnector connect;
  final Future<String?> Function() findAddress;

  final _changes = StreamController<Room?>.broadcast();
  late final StreamSubscription<Room?> _engineChanges;
  StreamSubscription<Room?>? _clientChanges;

  late GameService _active = engine;
  NearbyHost? _host;
  NearbyClientService? _client;
  bool _announcing = false;

  /// Where friends can reach a room this phone hosts, for typing in if
  /// it doesn't show up by itself. Null when not hosting.
  String? get hostAddress => _hostAddress;
  String? _hostAddress;

  @override
  Room? get room => _active.room;

  @override
  Stream<Room?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => _active.localPlayerId;

  @override
  Future<void> createRoom({
    required String playerName,
    required int playerCount,
    int avatarIndex = 0,
    GameSettings? settings,
    RoomMode mode = RoomMode.practice,
    bool fillWithBots = false,
  }) async {
    await _stopNearby();
    _active = engine;

    if (mode == RoomMode.nearby) {
      // Open the door for friends first, so a problem shows before the
      // lobby does.
      final NearbyServer server;
      try {
        server = await startServer();
      } on Object {
        throw const JoinRefused(
          "Couldn't open a room on this network. Check Wi-Fi or your hotspot.",
        );
      }
      _host = NearbyHost(engine: engine, server: server)..start();
      _hostAddress = await findAddress();
    }

    await engine.createRoom(
      playerName: playerName,
      playerCount: playerCount,
      avatarIndex: avatarIndex,
      settings: settings,
      mode: mode,
      fillWithBots: fillWithBots,
    );
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
  }) async {
    final found = finder.current.where((room) => room.code == roomCode);
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
    final client = NearbyClientService(connect: connect);
    // Switch over before joining, so the room the host sends straight after
    // its welcome isn't missed.
    _client = client;
    _active = client;
    _clientChanges = client.roomChanges.listen((room) {
      if (identical(_active, client)) _onRoom(room);
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
      await _clientChanges?.cancel();
      _clientChanges = null;
      _client = null;
      _active = engine;
      client.dispose();
      rethrow;
    }
  }

  /// Passes on each change, and tidies up when a room ends.
  void _onRoom(Room? room) {
    if (!_changes.isClosed) _changes.add(room);
    unawaited(_announce(room));
    if (room == null) unawaited(_stopNearby());
  }

  /// Announces a hosted room while it's waiting in the lobby for friends.
  Future<void> _announce(Room? room) async {
    final wanted =
        _host != null &&
        room != null &&
        room.phase == GamePhase.lobby &&
        room.players.length < LocalGameService.maxPlayers;
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
      );
    });
  }

  Future<void> _leaveCurrent() async {
    if (_active.room != null) await _active.leaveRoom();
    await _stopNearby();
  }

  Future<void> _stopNearby() async {
    final host = _host;
    final client = _client;
    _host = null;
    _client = null;
    _hostAddress = null;
    if (_announcing) {
      _announcing = false;
      await beacon.stop();
    }
    await host?.stop();
    if (client != null) {
      await _clientChanges?.cancel();
      _clientChanges = null;
      client.dispose();
      if (identical(_active, client)) _active = engine;
    }
  }

  @override
  Future<void> setReady(bool isReady) => _active.setReady(isReady);

  @override
  Future<void> startRound() => _active.startRound();

  @override
  Future<void> selectLetter(String letter) => _active.selectLetter(letter);

  @override
  Future<void> updateAnswer(Category category, String text) {
    return _active.updateAnswer(category, text);
  }

  @override
  Future<void> submitAnswers() => _active.submitAnswers();

  @override
  Future<void> castVote(String ballotItemId, VoteChoice choice) {
    return _active.castVote(ballotItemId, choice);
  }

  @override
  Future<void> nextRound() => _active.nextRound();

  @override
  Future<void> newGame() => _active.newGame();

  @override
  Future<void> refresh() => _active.refresh();

  @override
  Future<void> leaveRoom() async {
    final active = _active;
    await active.leaveRoom();
    await _stopNearby();
    _active = engine;
  }

  @override
  void dispose() {
    unawaited(_stopNearby());
    unawaited(_engineChanges.cancel());
    engine.dispose();
    _changes.close();
  }
}
