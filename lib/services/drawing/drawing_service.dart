import 'dart:async';

import '../../models/drawing_room.dart';
import '../../models/sketch.dart';

/// Everything the Guess the Drawing screens can ask of a game.
///
/// Screens only use this interface, so they don't know whether this phone
/// is the host or a guest, and tests can use a fake.
abstract interface class DrawingService {
  /// The room as this player sees it, or null when not in a game.
  DrawingRoom? get room;

  Stream<DrawingRoom?> get roomChanges;

  String? get localPlayerId;

  /// The current turn's drawing. It changes in place; [sketchChanges]
  /// says when.
  Sketch get sketch;

  Stream<void> get sketchChanges;

  /// Where friends can reach a room this phone hosts, for typing in if it
  /// doesn't show up by itself. Null when not hosting.
  String? get hostAddress;

  /// True in an online room, played through the internet.
  bool get isOnline;

  /// Opens a room on this phone, for friends nearby or, with [online],
  /// anywhere. Throws [JoinRefused] (from game_service.dart) if the
  /// network can't be used.
  Future<void> createRoom({
    required String playerName,
    required int avatarIndex,
    required int capacity,
    required DrawingSettings settings,
    bool online = false,
  });

  /// Joins a friend's room, nearby or [online]. Throws [JoinRefused] when
  /// it can't.
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  });

  Future<void> setReady(bool isReady);

  /// Only the host can start, once everyone is ready.
  Future<void> startGame();

  /// The drawer picks one of the three words.
  Future<void> chooseWord(int index);

  /// The drawer changes the drawing.
  void draw(SketchOp op);

  Future<void> guess(String text);

  Future<void> nextRound();

  /// Only the host, after the last round.
  Future<void> newGame();

  /// Checks the time again, for when the app returns from the background.
  Future<void> refresh();

  Future<void> leaveRoom();

  void dispose();
}

/// Groups drawing changes into small batches, so a moving finger sends a
/// message every [every] rather than one for every point.
class InkBatcher {
  InkBatcher({
    required this.send,
    this.every = const Duration(milliseconds: 40),
  });

  final void Function(int turnId, List<SketchOp> ops) send;
  final Duration every;

  int? _turnId;
  final _ops = <SketchOp>[];
  Timer? _timer;

  void add(int turnId, SketchOp op) {
    if (_turnId != null && _turnId != turnId) flush();
    _turnId = turnId;
    final last = _ops.isEmpty ? null : _ops.last;
    if (op is StrokeAdd && last is StrokeAdd) {
      _ops.last = StrokeAdd([...last.points, ...op.points]);
    } else if (op is StrokeAdd && last is StrokeStart) {
      _ops.last = StrokeStart(
        colour: last.colour,
        size: last.size,
        points: [...last.points, ...op.points],
      );
    } else {
      _ops.add(op);
    }
    _timer ??= Timer(every, flush);
  }

  /// Sends whatever is waiting now.
  void flush() {
    _timer?.cancel();
    _timer = null;
    final turnId = _turnId;
    if (_ops.isEmpty || turnId == null) return;
    final ops = [..._ops];
    _ops.clear();
    send(turnId, ops);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _ops.clear();
  }
}

/// The kinds of message phones send each other in Guess the Drawing.
abstract final class DrawingMessage {
  /// Sent with every greeting, so a phone can't join another game's room.
  static const game = 'guess_the_drawing';
  static const version = 1;

  // Guest to host.
  static const join = 'join';
  static const rejoin = 'rejoin';
  static const ready = 'ready';
  static const choose = 'choose';
  static const guess = 'guess';
  static const next = 'next';
  static const leave = 'leave';

  // Both ways.
  static const ink = 'ink';

  // Host to guest.
  static const welcome = 'welcome';
  static const refused = 'refused';
  static const room = 'room';
  static const sketch = 'sketch';
  static const closed = 'closed';
  static const removed = 'removed';
}
