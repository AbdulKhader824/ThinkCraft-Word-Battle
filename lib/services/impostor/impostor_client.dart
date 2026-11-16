import 'dart:async';

import '../../models/impostor_room.dart';
import '../game_service.dart';
import '../nearby/nearby_link.dart';
import 'impostor_codec.dart';
import 'impostor_service.dart';

/// Plays in a friend's Impostor room from a guest's phone. The host's
/// phone runs the game; this sends the player's moves and shows the room
/// the host sends back.
class ImpostorClient implements ImpostorService {
  ImpostorClient({
    required this.connect,
    this.reconnectTries = 5,
    this.reconnectGap = const Duration(seconds: 2),
  });

  final NearbyConnector connect;
  final int reconnectTries;
  final Duration reconnectGap;

  final _changes = StreamController<ImpostorRoom?>.broadcast();

  NearbyLink? _link;
  StreamSubscription<Map<String, Object?>>? _subscription;
  ImpostorRoom? _room;
  String? _playerId;
  String? _address;
  int? _port;
  bool _ended = false;
  Completer<void>? _greeting;

  @override
  ImpostorRoom? get room => _room;

  @override
  Stream<ImpostorRoom?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => _room == null ? null : _playerId;

  @override
  String? get hostAddress => null;

  /// Only the app's service knows; it makes this client for online rooms.
  @override
  bool get isOnline => false;

  Future<void> join({
    required String address,
    required int port,
    required String roomCode,
    required String playerName,
    required int avatarIndex,
  }) async {
    _ended = false;
    _address = address;
    _port = port;
    await _open({
      't': ImpostorMessage.join,
      'game': ImpostorMessage.game,
      'v': ImpostorMessage.version,
      'code': roomCode,
      'name': playerName,
      'avatar': avatarIndex,
    });
  }

  Future<void> _open(Map<String, Object?> hello) async {
    final NearbyLink link;
    try {
      link = await connect(_address!, _port!);
    } on JoinRefused {
      // An online room's relay says why, in words for the player.
      rethrow;
    } on Object {
      throw const JoinRefused(
        "Couldn't reach that room. Check you're on the same Wi-Fi.",
      );
    }
    _link = link;
    _greeting = Completer<void>();
    await _subscription?.cancel();
    _subscription = link.messages.listen(_handle);
    unawaited(link.done.then((_) => _onDropped(link)));

    link.send(hello);
    try {
      await _greeting!.future.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      await link.close();
      throw const JoinRefused("That room didn't answer. Try again.");
    }
  }

  void _handle(Map<String, Object?> message) {
    switch (message['t']) {
      case ImpostorMessage.welcome:
        _playerId = message['id']! as String;
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) greeting.complete();
      case ImpostorMessage.refused:
        _ended = true;
        final reason = message['reason'] as String? ?? "Couldn't join.";
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) {
          greeting.completeError(JoinRefused(reason));
        }
      case ImpostorMessage.room:
        _publish(
          ImpostorCodec.decode(message['room']! as Map<String, Object?>),
        );
      case ImpostorMessage.closed:
      case ImpostorMessage.removed:
        _end();
    }
  }

  Future<void> _onDropped(NearbyLink link) async {
    if (_ended || link != _link || _room == null) return;
    for (var attempt = 0; attempt < reconnectTries; attempt++) {
      await Future<void>.delayed(reconnectGap);
      if (_ended) return;
      try {
        await _open({
          't': ImpostorMessage.rejoin,
          'game': ImpostorMessage.game,
          'v': ImpostorMessage.version,
          'code': _room?.code,
          'id': _playerId,
        });
        return;
      } on JoinRefused {
        if (_ended) break;
      }
    }
    _end();
  }

  void _publish(ImpostorRoom? room) {
    _room = room;
    if (!_changes.isClosed) _changes.add(room);
  }

  void _end() {
    _ended = true;
    final link = _link;
    _link = null;
    unawaited(_subscription?.cancel());
    if (link != null) unawaited(link.close());
    if (_room != null) _publish(null);
  }

  void _send(Map<String, Object?> message) => _link?.send(message);

  @override
  Future<void> createRoom({
    required String playerName,
    required int avatarIndex,
    required int capacity,
    required ImpostorSettings settings,
    bool online = false,
  }) {
    throw UnsupportedError("A guest phone joins rooms; it doesn't make them.");
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  }) {
    if (hostAddress == null) {
      throw const JoinRefused('No room with that code was found nearby.');
    }
    return join(
      address: hostAddress,
      port: nearbyGamePort,
      roomCode: roomCode,
      playerName: playerName,
      avatarIndex: avatarIndex,
    );
  }

  @override
  Future<void> setReady(bool isReady) async {
    _send({'t': ImpostorMessage.ready, 'value': isReady});
  }

  @override
  Future<void> startGame() => throw StateError('Only the host can start.');

  @override
  Future<void> clueDone() async => _send({'t': ImpostorMessage.done});

  @override
  Future<void> voteNow() =>
      throw StateError('Only the host can start the vote.');

  @override
  Future<void> vote(String suspectId) async {
    _send({'t': ImpostorMessage.vote, 'suspect': suspectId});
  }

  @override
  Future<void> guessWord(String word) async {
    _send({'t': ImpostorMessage.guess, 'word': word});
  }

  @override
  Future<void> nextRound() async => _send({'t': ImpostorMessage.next});

  @override
  Future<void> newGame() =>
      throw StateError('Only the host can start a new game.');

  @override
  Future<void> refresh() async {}

  @override
  Future<void> leaveRoom() async {
    _send({'t': ImpostorMessage.leave});
    _end();
  }

  @override
  void dispose() {
    _ended = true;
    unawaited(_subscription?.cancel());
    unawaited(_link?.close());
    _changes.close();
  }
}
