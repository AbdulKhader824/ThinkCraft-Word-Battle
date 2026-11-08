import 'dart:async';

import '../../models/category.dart';
import '../../models/game_phase.dart';
import '../../models/game_settings.dart';
import '../../models/room.dart';
import '../../models/vote.dart';
import '../game_service.dart';
import 'nearby_host.dart';
import 'nearby_link.dart';
import 'room_codec.dart';

/// Plays in a friend's nearby room from a guest's phone. The host's phone
/// runs the game; this sends the player's moves and shows the room the
/// host sends back.
class NearbyClientService implements GameService {
  NearbyClientService({
    required this.connect,
    this.reconnectTries = 5,
    this.reconnectGap = const Duration(seconds: 2),
  });

  final NearbyConnector connect;

  /// If the connection drops, how often to try getting back in.
  final int reconnectTries;
  final Duration reconnectGap;

  final _changes = StreamController<Room?>.broadcast();
  NearbyLink? _link;
  StreamSubscription<Map<String, Object?>>? _subscription;
  Room? _room;
  String? _playerId;
  String? _address;
  int? _port;

  /// True once the session has ended on purpose, so a dropped connection
  /// isn't mistaken for a Wi-Fi hiccup.
  bool _ended = false;

  /// Answered by the host's welcome or refusal.
  Completer<void>? _greeting;

  /// Votes the host hasn't confirmed yet. They show on this phone straight
  /// away, and are sent again until the host has them.
  final _pendingVotes = <String, VoteChoice>{};
  Timer? _resendVotes;

  /// How long to wait for the host to confirm a vote before sending it
  /// again.
  static const voteResendGap = Duration(seconds: 2);

  @override
  Room? get room => _room;

  @override
  Stream<Room?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => _room == null ? null : _playerId;

  /// Joins the room [roomCode] run by the phone at [address].
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
      't': NearbyMessage.join,
      'v': NearbyMessage.version,
      'code': roomCode,
      'name': playerName,
      'avatar': avatarIndex,
    });
  }

  Future<void> _open(Map<String, Object?> hello) async {
    final NearbyLink link;
    try {
      link = await connect(_address!, _port!);
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
      case NearbyMessage.welcome:
        _playerId = message['id']! as String;
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) greeting.complete();
      case NearbyMessage.refused:
        _ended = true;
        final reason = message['reason'] as String? ?? "Couldn't join.";
        final greeting = _greeting;
        if (greeting != null && !greeting.isCompleted) {
          greeting.completeError(JoinRefused(reason));
        }
      case NearbyMessage.room:
        _receive(RoomCodec.decode(message['room']! as Map<String, Object?>));
      case NearbyMessage.closed:
      case NearbyMessage.removed:
        _end();
    }
  }

  /// The connection ended. If the game is still on, try to get back in.
  Future<void> _onDropped(NearbyLink link) async {
    if (_ended || link != _link || _room == null) return;

    for (var attempt = 0; attempt < reconnectTries; attempt++) {
      await Future<void>.delayed(reconnectGap);
      if (_ended) return;
      try {
        await _open({
          't': NearbyMessage.rejoin,
          'v': NearbyMessage.version,
          'code': _room?.code,
          'id': _playerId,
        });
        _sendPendingVotes();
        return;
      } on JoinRefused {
        if (_ended) break;
      }
    }
    _end();
  }

  void _publish(Room? room) {
    _room = room;
    if (!_changes.isClosed) _changes.add(room);
  }

  /// A room from the host. Votes it has now are confirmed; any still on
  /// their way are shown as made, so the screen doesn't step back.
  void _receive(Room room) {
    final round = room.round;
    if (round == null || room.phase != GamePhase.validating) {
      _clearPendingVotes();
      _publish(room);
      return;
    }
    _pendingVotes.removeWhere((item, _) => round.myVotes.containsKey(item));
    if (_pendingVotes.isEmpty) _stopResending();
    _publish(_withPendingVotes(room));
  }

  Room _withPendingVotes(Room room) {
    final round = room.round;
    if (round == null || _pendingVotes.isEmpty) return room;
    final onBallot = {for (final item in round.ballot) item.id};
    return room.copyWith(
      round: round.copyWith(
        myVotes: {
          ...round.myVotes,
          for (final MapEntry(:key, :value) in _pendingVotes.entries)
            if (onBallot.contains(key)) key: value,
        },
      ),
    );
  }

  void _sendPendingVotes() {
    for (final MapEntry(key: item, value: choice) in _pendingVotes.entries) {
      _send({'t': NearbyMessage.vote, 'item': item, 'choice': choice.name});
    }
  }

  void _stopResending() {
    _resendVotes?.cancel();
    _resendVotes = null;
  }

  void _clearPendingVotes() {
    _pendingVotes.clear();
    _stopResending();
  }

  void _end() {
    _ended = true;
    _clearPendingVotes();
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
    required int playerCount,
    int avatarIndex = 0,
    GameSettings? settings,
    RoomMode mode = RoomMode.practice,
    bool fillWithBots = false,
  }) {
    throw UnsupportedError('A guest phone joins rooms; it doesn\'t make them.');
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
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
    _send({'t': NearbyMessage.ready, 'value': isReady});
  }

  @override
  Future<void> startRound() {
    throw StateError('Only the host can start.');
  }

  @override
  Future<void> selectLetter(String letter) async {
    _send({'t': NearbyMessage.letter, 'letter': letter});
  }

  @override
  Future<void> updateAnswer(Category category, String text) async {
    _send({'t': NearbyMessage.answer, 'category': category.name, 'text': text});
  }

  @override
  Future<void> submitAnswers() async => _send({'t': NearbyMessage.submit});

  @override
  Future<void> castVote(String ballotItemId, VoteChoice choice) async {
    final room = _room;
    if (room == null || room.phase != GamePhase.validating) return;
    if (room.round!.myVotes.containsKey(ballotItemId)) return;

    _pendingVotes[ballotItemId] = choice;
    _send({
      't': NearbyMessage.vote,
      'item': ballotItemId,
      'choice': choice.name,
    });
    // Shows the next answer at once, without waiting for the host.
    _publish(_withPendingVotes(room));
    _resendVotes ??= Timer.periodic(voteResendGap, (_) {
      if (_pendingVotes.isEmpty) {
        _stopResending();
      } else {
        _sendPendingVotes();
      }
    });
  }

  @override
  Future<void> nextRound() async => _send({'t': NearbyMessage.next});

  @override
  Future<void> newGame() {
    throw StateError('Only the host can start a new game.');
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> leaveRoom() async {
    _send({'t': NearbyMessage.leave});
    _end();
  }

  @override
  void dispose() {
    _ended = true;
    _clearPendingVotes();
    unawaited(_subscription?.cancel());
    unawaited(_link?.close());
    _changes.close();
  }
}
