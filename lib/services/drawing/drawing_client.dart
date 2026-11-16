import 'dart:async';

import '../../models/drawing_room.dart';
import '../../models/sketch.dart';
import '../game_service.dart';
import '../nearby/nearby_link.dart';
import 'drawing_codec.dart';
import 'drawing_service.dart';

/// Plays in a friend's Guess the Drawing room from a guest's phone. The
/// host's phone runs the game; this sends the player's moves and strokes,
/// and shows the room and drawing the host sends back.
class DrawingClient implements DrawingService {
  DrawingClient({
    required this.connect,
    this.reconnectTries = 5,
    this.reconnectGap = const Duration(seconds: 2),
  }) {
    _batcher = InkBatcher(
      send: (turnId, ops) => _send({
        't': DrawingMessage.ink,
        'turn': turnId,
        'ops': [for (final op in ops) op.toJson()],
      }),
    );
  }

  final NearbyConnector connect;
  final int reconnectTries;
  final Duration reconnectGap;

  final _changes = StreamController<DrawingRoom?>.broadcast();
  final _sketchChanges = StreamController<void>.broadcast();
  late final InkBatcher _batcher;

  NearbyLink? _link;
  StreamSubscription<Map<String, Object?>>? _subscription;
  DrawingRoom? _room;
  String? _playerId;
  String? _address;
  int? _port;
  bool _ended = false;
  Completer<void>? _greeting;

  @override
  final sketch = Sketch();

  /// The turn [sketch] belongs to.
  int _sketchTurn = -1;

  @override
  DrawingRoom? get room => _room;

  @override
  Stream<DrawingRoom?> get roomChanges => _changes.stream;

  @override
  Stream<void> get sketchChanges => _sketchChanges.stream;

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
      't': DrawingMessage.join,
      'game': DrawingMessage.game,
      'v': DrawingMessage.version,
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
      case DrawingMessage.welcome:
        _playerId = message['id']! as String;
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) greeting.complete();
      case DrawingMessage.refused:
        _ended = true;
        final reason = message['reason'] as String? ?? "Couldn't join.";
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) {
          greeting.completeError(JoinRefused(reason));
        }
      case DrawingMessage.room:
        _receive(DrawingCodec.decode(message['room']! as Map<String, Object?>));
      case DrawingMessage.ink:
        if (message['turn'] != _sketchTurn) return;
        for (final op in message['ops']! as List<Object?>) {
          sketch.apply(SketchOp.fromJson(op! as Map<String, Object?>));
        }
        _sketchChanged();
      case DrawingMessage.sketch:
        if (message['turn'] != _sketchTurn) return;
        sketch.replaceWith(Sketch.strokesFromJson(message['strokes']));
        _sketchChanged();
      case DrawingMessage.closed:
      case DrawingMessage.removed:
        _end();
    }
  }

  void _receive(DrawingRoom room) {
    if (room.turnId != _sketchTurn) {
      // A new turn starts with a clean page.
      _batcher.dispose();
      _sketchTurn = room.turnId;
      sketch.clear();
      _sketchChanged();
    }
    _publish(room);
  }

  void _sketchChanged() {
    if (!_sketchChanges.isClosed) _sketchChanges.add(null);
  }

  Future<void> _onDropped(NearbyLink link) async {
    if (_ended || link != _link || _room == null) return;
    for (var attempt = 0; attempt < reconnectTries; attempt++) {
      await Future<void>.delayed(reconnectGap);
      if (_ended) return;
      try {
        await _open({
          't': DrawingMessage.rejoin,
          'game': DrawingMessage.game,
          'v': DrawingMessage.version,
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

  void _publish(DrawingRoom? room) {
    _room = room;
    if (!_changes.isClosed) _changes.add(room);
  }

  void _end() {
    _ended = true;
    _batcher.dispose();
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
    required DrawingSettings settings,
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
    _send({'t': DrawingMessage.ready, 'value': isReady});
  }

  @override
  Future<void> startGame() => throw StateError('Only the host can start.');

  @override
  Future<void> chooseWord(int index) async {
    _send({'t': DrawingMessage.choose, 'index': index});
  }

  @override
  void draw(SketchOp op) {
    final room = _room;
    if (room == null ||
        room.phase != DrawingPhase.drawing ||
        room.drawerId != _playerId) {
      return;
    }
    // Shown at once here, and sent to the host in small batches.
    sketch.apply(op);
    _sketchChanged();
    _batcher.add(room.turnId, op);
  }

  @override
  Future<void> guess(String text) async {
    _send({'t': DrawingMessage.guess, 'text': text});
  }

  @override
  Future<void> nextRound() async => _send({'t': DrawingMessage.next});

  @override
  Future<void> newGame() =>
      throw StateError('Only the host can start a new game.');

  @override
  Future<void> refresh() async {}

  @override
  Future<void> leaveRoom() async {
    _batcher.flush();
    _send({'t': DrawingMessage.leave});
    _end();
  }

  @override
  void dispose() {
    _ended = true;
    _batcher.dispose();
    unawaited(_subscription?.cancel());
    unawaited(_link?.close());
    _changes.close();
    _sketchChanges.close();
  }
}
