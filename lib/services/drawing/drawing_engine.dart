import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../../models/drawing_room.dart';
import '../../models/player.dart';
import '../../models/sketch.dart';
import '../drawing_words.dart';
import '../game_service.dart';
import '../rules/drawing_rules.dart';
import '../rules/room_input_rules.dart';
import '../rules/rude_words.dart';

/// A change to the drawing, from the drawer, during turn [turnId].
class InkEvent {
  const InkEvent({
    required this.turnId,
    required this.op,
    required this.authorId,
  });

  final int turnId;
  final SketchOp op;
  final String authorId;
}

/// Runs a Guess the Drawing room on the host's phone: the turns, timers,
/// words, guesses and scores. Moves from every phone come in through the
/// methods that take a player id; [roomFor] gives each player only what
/// they may see.
///
/// It's plain Dart, so the rules can be tested without a screen.
class DrawingEngine {
  DrawingEngine({Random? random}) : _random = random ?? Random();

  /// The host's own player id.
  static const hostId = 'host';

  final Random _random;
  final _changes = StreamController<DrawingRoom?>.broadcast();
  final _ink = StreamController<InkEvent>.broadcast();

  /// The drawing for the current turn.
  final sketch = Sketch();

  DrawingRoom? _room;
  int _nextGuestNumber = 1;

  // The current turn, which only the host knows in full.
  List<String> _choices = const [];
  String? _word;
  List<int> _hintOrder = const [];
  final _revealed = <int>{};
  final _usedWords = <String>{};

  // Who draws this round, in order, and whose turn it is.
  List<String> _order = const [];
  int _orderIndex = -1;

  Timer? _stageTimer;
  final _hintTimers = <Timer>[];

  /// The whole room, as the host knows it.
  DrawingRoom? get room => _room;

  /// Every change to the room.
  Stream<DrawingRoom?> get roomChanges => _changes.stream;

  /// Every change to the drawing, as the drawer makes it.
  Stream<InkEvent> get inkChanges => _ink.stream;

  /// The word being drawn. Only for tests and the host's own checks.
  String? get currentWord => _word;

  // ----------------------------------------------------------------- rooms

  void createRoom({
    required String hostName,
    required int avatarIndex,
    required int capacity,
    required DrawingSettings settings,
  }) {
    _clearTimers();
    sketch.clear();
    _usedWords.clear();
    _nextGuestNumber = 1;
    _publish(
      DrawingRoom(
        code: _newCode(),
        settings: settings,
        capacity: capacity.clamp(
          RoomInputRules.minPlayers,
          RoomInputRules.maxPlayers,
        ),
        players: [
          Player(
            id: hostId,
            name: hostName,
            avatarIndex: avatarIndex,
            isHost: true,
            isReady: true,
          ),
        ],
      ),
    );
  }

  /// Adds a player from another phone to the lobby, and returns their id.
  String addPlayer({required String name, required int avatarIndex}) {
    final room = _room;
    if (room == null) throw const JoinRefused('That room has closed.');
    if (room.phase != DrawingPhase.lobby) {
      throw const JoinRefused('That game has already started.');
    }
    if (room.players.length >= room.capacity) {
      throw const JoinRefused('That room is full.');
    }
    final id = 'guest-${_nextGuestNumber++}';
    _publish(
      room.copyWith(
        players: [
          ...room.players,
          Player(id: id, name: name, avatarIndex: avatarIndex),
        ],
      ),
    );
    return id;
  }

  bool hasPlayer(String playerId) => _room?.playerOrNull(playerId) != null;

  /// A player's phone lost its connection, or came back.
  void setAway(String playerId, {required bool away}) {
    final room = _room;
    if (room == null || !hasPlayer(playerId)) return;
    if (away && room.phase == DrawingPhase.lobby) {
      removePlayer(playerId);
      return;
    }
    if (away == room.awayIds.contains(playerId)) return;
    _publish(
      room.copyWith(
        awayIds: away
            ? {...room.awayIds, playerId}
            : ({...room.awayIds}..remove(playerId)),
      ),
    );
    if (away) _afterSomeoneWent(playerId);
  }

  /// A player left on purpose. If the host leaves, or fewer than two
  /// players are left in a game, the room closes.
  void removePlayer(String playerId) {
    final room = _room;
    if (room == null || !hasPlayer(playerId)) return;
    if (playerId == hostId) {
      close();
      return;
    }
    final players = [
      for (final player in room.players)
        if (player.id != playerId) player,
    ];
    if (room.phase != DrawingPhase.lobby && players.length < 2) {
      close();
      return;
    }
    _publish(
      room.copyWith(
        players: players,
        awayIds: {...room.awayIds}..remove(playerId),
        readyIds: {...room.readyIds}..remove(playerId),
        scores: {...room.scores}..remove(playerId),
      ),
    );
    _afterSomeoneWent(playerId);
  }

  /// The game carries on without a player who has gone.
  void _afterSomeoneWent(String playerId) {
    final room = _room!;
    switch (room.phase) {
      case DrawingPhase.choosing || DrawingPhase.drawing
          when room.drawerId == playerId:
        _endTurn(TurnEnd.drawerLeft);
      case DrawingPhase.drawing:
        _checkEveryoneGuessed();
      case DrawingPhase.results:
        _checkEveryoneReady();
      default:
        break;
    }
  }

  void setReady(String playerId, bool isReady) {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.lobby) return;
    if (playerId == hostId) return;
    _publish(
      room.copyWith(
        players: [
          for (final player in room.players)
            player.id == playerId ? player.copyWith(isReady: isReady) : player,
        ],
      ),
    );
  }

  /// The host starts the game once everyone is ready.
  void startGame(String playerId) {
    final room = _room;
    if (room == null || playerId != hostId) return;
    if (room.phase != DrawingPhase.lobby || !room.canStart) return;
    _publish(room.copyWith(scores: const {}, awayIds: const {}));
    _beginRound(1);
  }

  /// After the last round, the host plays again with the same players.
  void newGame(String playerId) {
    final room = _room;
    if (room == null || playerId != hostId || !room.isGameOver) return;
    _publish(room.copyWith(scores: const {}, round: 0));
    _beginRound(1);
  }

  // ----------------------------------------------------------------- turns

  void _beginRound(int number) {
    final room = _room!;
    _order = [
      for (final player in room.players)
        if (!room.awayIds.contains(player.id)) player.id,
    ];
    _orderIndex = -1;
    _publish(room.copyWith(round: number, readyIds: const {}));
    _nextTurn();
  }

  void _nextTurn() {
    _clearTimers();
    final room = _room!;
    do {
      _orderIndex++;
    } while (_orderIndex < _order.length &&
        (!hasPlayer(_order[_orderIndex]) ||
            room.awayIds.contains(_order[_orderIndex])));

    if (_orderIndex >= _order.length) {
      _endRound();
      return;
    }

    _choices = DrawingWords.pick(
      room.settings.wordLevel,
      _random,
      used: _usedWords,
    );
    _word = null;
    _hintOrder = const [];
    _revealed.clear();
    sketch.clear();
    _publish(
      room.copyWith(
        phase: DrawingPhase.choosing,
        turnId: room.turnId + 1,
        turnInRound: _orderIndex + 1,
        turnsInRound: _order.length,
        drawerId: () => _order[_orderIndex],
        guessedIds: const [],
        feed: const [],
        turnPoints: const {},
        turnEnd: () => null,
        deadline: () => clock.now().add(DrawingRoom.chooseTime),
      ),
    );
    _stageTimer = Timer(DrawingRoom.chooseTime, _onDeadline);
  }

  /// The drawer picks one of the three words.
  void chooseWord(String playerId, int index) {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.choosing) return;
    if (playerId != room.drawerId || index < 0 || index >= _choices.length) {
      return;
    }
    _clearTimers();
    final word = _choices[index];
    _word = word;
    _usedWords.add(word);
    final positions = DrawingRules.letterPositions(word)..shuffle(_random);
    _hintOrder = positions.take(DrawingRules.hintCount(word)).toList();

    final drawTime = room.settings.drawTime;
    _publish(
      room.copyWith(
        phase: DrawingPhase.drawing,
        deadline: () => clock.now().add(drawTime),
      ),
    );
    _stageTimer = Timer(drawTime, _onDeadline);
    for (final (index, share) in DrawingRules.hintTimes.indexed) {
      if (index >= _hintOrder.length) break;
      _hintTimers.add(
        Timer(drawTime * share, () {
          _revealed.add(_hintOrder[index]);
          if (_room?.phase == DrawingPhase.drawing) _publish(_room);
        }),
      );
    }
  }

  /// The drawer changes the drawing.
  void draw(String playerId, int turnId, SketchOp op) {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.drawing) return;
    if (playerId != room.drawerId || turnId != room.turnId) return;
    sketch.apply(op);
    _ink.add(InkEvent(turnId: turnId, op: op, authorId: playerId));
  }

  /// A guesser types a guess.
  void guess(String playerId, String text) {
    final room = _room;
    final word = _word;
    if (room == null || word == null || room.phase != DrawingPhase.drawing) {
      return;
    }
    if (playerId == room.drawerId ||
        !hasPlayer(playerId) ||
        room.guessedIds.contains(playerId)) {
      return;
    }
    final guess = DrawingRules.cleanGuess(text);
    if (guess.isEmpty) return;

    if (DrawingRules.isCorrect(guess, word)) {
      _publish(
        room.copyWith(
          guessedIds: [...room.guessedIds, playerId],
          feed: _withEntry(
            room.feed,
            FeedEntry(playerId: playerId, kind: FeedKind.correct),
          ),
        ),
      );
      _checkEveryoneGuessed();
      return;
    }

    final FeedKind kind;
    if (DrawingRules.isClose(guess, word)) {
      kind = FeedKind.close;
    } else if (soundsRude(guess)) {
      // Rude guesses are never shown to anyone.
      return;
    } else {
      kind = FeedKind.guess;
    }
    _publish(
      room.copyWith(
        feed: _withEntry(
          room.feed,
          FeedEntry(playerId: playerId, kind: kind, text: guess),
        ),
      ),
    );
  }

  List<FeedEntry> _withEntry(List<FeedEntry> feed, FeedEntry entry) {
    final all = [...feed, entry];
    return all.length > DrawingRules.feedLength
        ? all.sublist(all.length - DrawingRules.feedLength)
        : all;
  }

  /// The players who could guess this turn: everyone here but the drawer.
  List<String> _guessers(DrawingRoom room) => [
    for (final player in room.players)
      if (player.id != room.drawerId && !room.awayIds.contains(player.id))
        player.id,
  ];

  void _checkEveryoneGuessed() {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.drawing) return;
    final guessers = _guessers(room);
    if (room.guessedIds.isEmpty) return;
    if (guessers.every(room.guessedIds.contains)) {
      _endTurn(TurnEnd.allGuessed);
    }
  }

  void _endTurn(TurnEnd reason) {
    _clearTimers();
    final room = _room!;
    final points = <String, int>{};
    final scores = {...room.scores};
    final drawerId = room.drawerId;

    if (reason != TurnEnd.drawerLeft && drawerId != null) {
      for (final (order, id) in room.guessedIds.indexed) {
        if (!hasPlayer(id)) continue;
        final won = DrawingRules.pointsForGuess(order);
        points[id] = won;
        scores[id] = room.scoreOf(id).add(won, star: order == 0);
      }
      final guessers = {..._guessers(room), ...room.guessedIds};
      final drawerWon = DrawingRules.drawerPoints(
        guessed: room.guessedIds.length,
        guessers: guessers.length,
      );
      if (hasPlayer(drawerId)) {
        points[drawerId] = drawerWon;
        scores[drawerId] = room.scoreOf(drawerId).add(drawerWon);
      }
    }

    _publish(
      room.copyWith(
        phase: DrawingPhase.turnResult,
        turnPoints: points,
        turnEnd: () => reason,
        scores: scores,
        deadline: () => clock.now().add(DrawingRoom.turnResultTime),
      ),
    );
    _stageTimer = Timer(DrawingRoom.turnResultTime, _onDeadline);
  }

  void _endRound() {
    final room = _room!;
    final last = room.isFinalRound;
    _publish(
      room.copyWith(
        phase: DrawingPhase.results,
        drawerId: () => null,
        readyIds: const {},
        deadline: () =>
            last ? null : clock.now().add(DrawingRoom.nextRoundWait),
      ),
    );
    if (!last) _stageTimer = Timer(DrawingRoom.nextRoundWait, _onDeadline);
  }

  /// A player pressed Next Round.
  void nextRound(String playerId) {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.results) return;
    if (room.isFinalRound || !hasPlayer(playerId)) return;
    _publish(room.copyWith(readyIds: {...room.readyIds, playerId}));
    _checkEveryoneReady();
  }

  void _checkEveryoneReady() {
    final room = _room;
    if (room == null || room.phase != DrawingPhase.results) return;
    if (room.isFinalRound) return;
    final here = [
      for (final player in room.players)
        if (!room.awayIds.contains(player.id)) player.id,
    ];
    if (here.every(room.readyIds.contains)) _beginRound(room.round + 1);
  }

  /// Next Round waited long enough: players who didn't press it leave,
  /// except the host, and the round starts with the rest.
  void _closeNextRoundWait() {
    final room = _room!;
    final staying = [
      for (final player in room.players)
        if (player.isHost || room.readyIds.contains(player.id)) player,
    ];
    if (staying.length < 2) {
      close();
      return;
    }
    final ids = {for (final player in staying) player.id};
    _publish(
      room.copyWith(
        players: staying,
        awayIds: room.awayIds.intersection(ids),
        scores: {
          for (final MapEntry(:key, :value) in room.scores.entries)
            if (ids.contains(key)) key: value,
        },
      ),
    );
    _beginRound(room.round + 1);
  }

  void _onDeadline() {
    final room = _room;
    if (room == null) return;
    switch (room.phase) {
      case DrawingPhase.choosing:
        // Too slow to pick: a word is picked for them.
        chooseWord(room.drawerId!, _random.nextInt(_choices.length));
      case DrawingPhase.drawing:
        _endTurn(TurnEnd.timeUp);
      case DrawingPhase.turnResult:
        _nextTurn();
      case DrawingPhase.results:
        if (!room.isFinalRound) _closeNextRoundWait();
      case DrawingPhase.lobby:
        break;
    }
  }

  /// Checks the time again, for when the app returns from the background.
  void refresh() {
    final deadline = _room?.deadline;
    if (deadline != null && !clock.now().isBefore(deadline)) {
      _stageTimer?.cancel();
      _onDeadline();
    }
  }

  // ----------------------------------------------------------------- views

  /// The room as [playerId] may see it.
  DrawingRoom? roomFor(String playerId) {
    final room = _room;
    if (room == null) return null;
    final isDrawer = playerId == room.drawerId;
    final word = _word;

    final String? shownWord;
    String? mask;
    switch (room.phase) {
      case DrawingPhase.drawing:
        shownWord = isDrawer || room.guessedIds.contains(playerId)
            ? word
            : null;
        mask = word == null ? null : DrawingRules.mask(word, _revealed);
      case DrawingPhase.turnResult:
        shownWord = word;
      default:
        shownWord = null;
    }

    return room.copyWith(
      choices: isDrawer && room.phase == DrawingPhase.choosing
          ? _choices
          : const [],
      word: () => shownWord,
      wordMask: () => mask,
      feed: [
        for (final entry in room.feed)
          if (entry.kind != FeedKind.close || entry.playerId == playerId) entry,
      ],
    );
  }

  // ---------------------------------------------------------------- inside

  void _publish(DrawingRoom? room) {
    _room = room;
    if (!_changes.isClosed) _changes.add(room);
  }

  void _clearTimers() {
    _stageTimer?.cancel();
    _stageTimer = null;
    for (final timer in _hintTimers) {
      timer.cancel();
    }
    _hintTimers.clear();
  }

  String _newCode() {
    const characters = RoomInputRules.roomCodeCharacters;
    return List.generate(
      RoomInputRules.roomCodeLength,
      (_) => characters[_random.nextInt(characters.length)],
    ).join();
  }

  /// Ends the room for everyone.
  void close() {
    _clearTimers();
    _word = null;
    _choices = const [];
    sketch.clear();
    _publish(null);
  }

  void dispose() {
    _clearTimers();
    _changes.close();
    _ink.close();
  }
}
