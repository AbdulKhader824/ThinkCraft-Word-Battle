import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../../models/impostor_room.dart';
import '../../models/player.dart';
import '../game_service.dart';
import '../impostor_words.dart';
import '../rules/impostor_rules.dart';
import '../rules/room_input_rules.dart';

/// Runs an Impostor room on the host's phone: the rounds, timers, words,
/// clue turns, votes and scores. Moves from every phone come in through
/// the methods that take a player id; [roomFor] gives each player only
/// what they may see.
///
/// It's plain Dart, so the rules can be tested without a screen.
class ImpostorEngine {
  ImpostorEngine({Random? random}) : _random = random ?? Random();

  /// The host's own player id.
  static const hostId = 'host';

  final Random _random;
  final _changes = StreamController<ImpostorRoom?>.broadcast();

  /// The whole room, secrets included. Players only ever get [roomFor].
  ImpostorRoom? _room;
  int _nextGuestNumber = 1;

  final _usedWords = <String>{};
  final _timesImpostor = <String, int>{};

  Timer? _stageTimer;

  /// The whole room, as the host's phone knows it. Screens use [roomFor].
  ImpostorRoom? get room => _room;

  /// Every change to the room.
  Stream<ImpostorRoom?> get roomChanges => _changes.stream;

  // ----------------------------------------------------------------- rooms

  /// Opens a room. An online room passes the [code] the relay holds for it.
  void createRoom({
    required String hostName,
    required int avatarIndex,
    required int capacity,
    required ImpostorSettings settings,
    String? code,
  }) {
    _clearTimer();
    _usedWords.clear();
    _timesImpostor.clear();
    _nextGuestNumber = 1;
    _publish(
      ImpostorRoom(
        code: code ?? _newCode(),
        settings: settings,
        capacity: capacity.clamp(
          ImpostorRoom.minPlayers,
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
    if (room.phase != ImpostorPhase.lobby) {
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
    if (away && room.phase == ImpostorPhase.lobby) {
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

  /// A player left on purpose. If the host leaves, or fewer than three
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
    if (room.phase != ImpostorPhase.lobby &&
        players.length < ImpostorRoom.minPlayers) {
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

  /// True while a round is being played, before its results.
  bool _inRound(ImpostorPhase phase) =>
      phase != ImpostorPhase.lobby && phase != ImpostorPhase.results;

  /// The game carries on without a player who has gone.
  void _afterSomeoneWent(String playerId) {
    final room = _room!;
    if (_inRound(room.phase) && playerId == room.impostorId) {
      _endRound(RoundEnd.impostorLeft);
      return;
    }
    switch (room.phase) {
      case ImpostorPhase.clues when room.speakerId == playerId:
        _nextClue();
      case ImpostorPhase.vote:
        _checkEveryoneVoted();
      case ImpostorPhase.results:
        _checkEveryoneReady();
      default:
        break;
    }
  }

  void setReady(String playerId, bool isReady) {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.lobby) return;
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
    if (room.phase != ImpostorPhase.lobby || !room.canStart) return;
    _timesImpostor.clear();
    _publish(room.copyWith(scores: const {}, awayIds: const {}));
    _beginRound(1);
  }

  /// After the last round, the host plays again with the same players.
  void newGame(String playerId) {
    final room = _room;
    if (room == null || playerId != hostId || !room.isGameOver) return;
    _timesImpostor.clear();
    _publish(room.copyWith(scores: const {}, round: 0));
    _beginRound(1);
  }

  // ---------------------------------------------------------------- rounds

  List<String> _here(ImpostorRoom room) => [
    for (final player in room.players)
      if (!room.awayIds.contains(player.id)) player.id,
  ];

  void _beginRound(int number) {
    _clearTimer();
    final room = _room!;
    final here = _here(room);
    final impostorId = ImpostorRules.pickImpostor(
      here,
      _timesImpostor,
      _random,
    );
    _timesImpostor[impostorId] = (_timesImpostor[impostorId] ?? 0) + 1;
    final pick = ImpostorWords.pick(
      room.settings.topics,
      _random,
      used: _usedWords,
    );
    _usedWords.add(pick.word);

    _enter(
      room.copyWith(
        phase: ImpostorPhase.word,
        round: number,
        topic: () => pick.topic,
        word: () => pick.word,
        impostorId: () => impostorId,
        clueOrder: ImpostorRules.clueOrder(
          here,
          impostorId,
          room.settings.clueTurns,
          _random,
        ),
        clueIndex: 0,
        votes: const {},
        votedIds: const {},
        guessChoices: pick.choices,
        guessedWord: () => null,
        caught: () => null,
        roundEnd: () => null,
        roundPoints: const {},
        readyIds: const {},
      ),
      ImpostorRoom.wordTime,
    );
  }

  /// Moves on to the next player here to give a clue, or to talking it
  /// over once everyone has had their turns. [from] is where to start
  /// looking.
  void _nextClue({int? from}) {
    final room = _room!;
    var index = from ?? room.clueIndex + 1;
    while (index < room.clueOrder.length &&
        (!hasPlayer(room.clueOrder[index]) ||
            room.awayIds.contains(room.clueOrder[index]))) {
      index++;
    }
    if (index >= room.clueOrder.length) {
      _enter(room.copyWith(phase: ImpostorPhase.talk), ImpostorRoom.talkTime);
      return;
    }
    _enter(
      room.copyWith(phase: ImpostorPhase.clues, clueIndex: index),
      room.settings.clueTime,
    );
  }

  /// The speaker says they've given their clue.
  void clueDone(String playerId) {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.clues) return;
    if (room.speakerId != playerId) return;
    _nextClue();
  }

  /// The host ends the talking and starts the vote.
  void voteNow(String playerId) {
    final room = _room;
    if (room == null || playerId != hostId) return;
    if (room.phase != ImpostorPhase.talk) return;
    _startVote();
  }

  void _startVote() {
    _enter(_room!.copyWith(phase: ImpostorPhase.vote), ImpostorRoom.voteTime);
  }

  /// A secret vote for who the Impostor is. A vote can't be changed, and
  /// nobody can vote for themselves.
  void vote(String playerId, String suspectId) {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.vote) return;
    if (!hasPlayer(playerId) || !hasPlayer(suspectId)) return;
    if (playerId == suspectId || room.votes.containsKey(playerId)) return;
    _publish(
      room.copyWith(
        votes: {...room.votes, playerId: suspectId},
        votedIds: {...room.votedIds, playerId},
      ),
    );
    _checkEveryoneVoted();
  }

  void _checkEveryoneVoted() {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.vote) return;
    if (_here(room).every(room.votes.containsKey)) _reveal();
  }

  void _reveal() {
    final room = _room!;
    _enter(
      room.copyWith(
        phase: ImpostorPhase.reveal,
        caught: () => ImpostorRules.isCaught(room.votes, room.impostorId!),
      ),
      ImpostorRoom.revealTime,
    );
  }

  /// The Impostor picks the word, caught or not.
  void guessWord(String playerId, String word) {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.guess) return;
    if (playerId != room.impostorId || !room.guessChoices.contains(word)) {
      return;
    }
    _publish(room.copyWith(guessedWord: () => word));
    _endRound(RoundEnd.played);
  }

  void _endRound(RoundEnd reason) {
    _clearTimer();
    final room = _room!;
    final scores = {...room.scores};
    var points = const <String, int>{};
    if (reason == RoundEnd.played) {
      final impostorId = room.impostorId!;
      points = ImpostorRules.roundPoints(
        playerIds: _here(room),
        impostorId: impostorId,
        votes: room.votes,
        guessedRight: room.guessedRight,
      );
      for (final MapEntry(key: id, value: won) in points.entries) {
        scores[id] = room
            .scoreOf(id)
            .add(
              won,
              rightVote: room.votes[id] == impostorId,
              asImpostor: id == impostorId,
            );
      }
    }
    final last = room.isFinalRound;
    _publish(
      room.copyWith(
        phase: ImpostorPhase.results,
        roundEnd: () => reason,
        caught: () => reason == RoundEnd.played ? room.caught : null,
        roundPoints: points,
        scores: scores,
        readyIds: const {},
        deadline: () =>
            last ? null : clock.now().add(ImpostorRoom.nextRoundWait),
      ),
    );
    if (!last) _stageTimer = Timer(ImpostorRoom.nextRoundWait, _onDeadline);
  }

  /// A player pressed Next Round.
  void nextRound(String playerId) {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.results) return;
    if (room.isFinalRound || !hasPlayer(playerId)) return;
    _publish(room.copyWith(readyIds: {...room.readyIds, playerId}));
    _checkEveryoneReady();
  }

  void _checkEveryoneReady() {
    final room = _room;
    if (room == null || room.phase != ImpostorPhase.results) return;
    if (room.isFinalRound) return;
    if (_here(room).every(room.readyIds.contains)) _beginRound(room.round + 1);
  }

  /// Next Round waited long enough: players who didn't press it leave,
  /// except the host, and the round starts with the rest.
  void _closeNextRoundWait() {
    final room = _room!;
    final staying = [
      for (final player in room.players)
        if (player.isHost || room.readyIds.contains(player.id)) player,
    ];
    if (staying.length < ImpostorRoom.minPlayers) {
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

  /// Moves to [next], a new stage lasting [length].
  void _enter(ImpostorRoom next, Duration length) {
    _clearTimer();
    _publish(next.copyWith(deadline: () => clock.now().add(length)));
    _stageTimer = Timer(length, _onDeadline);
  }

  void _onDeadline() {
    final room = _room;
    if (room == null) return;
    switch (room.phase) {
      case ImpostorPhase.word:
        _nextClue(from: 0);
      case ImpostorPhase.clues:
        _nextClue();
      case ImpostorPhase.talk:
        _startVote();
      case ImpostorPhase.vote:
        _reveal();
      case ImpostorPhase.reveal:
        _enter(
          room.copyWith(phase: ImpostorPhase.guess),
          ImpostorRoom.guessTime,
        );
      case ImpostorPhase.guess:
        // Out of time counts as a wrong guess.
        _endRound(RoundEnd.played);
      case ImpostorPhase.results:
        if (!room.isFinalRound) _closeNextRoundWait();
      case ImpostorPhase.lobby:
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
  ImpostorRoom? roomFor(String playerId) {
    final room = _room;
    if (room == null) return null;
    final phase = room.phase;
    final isImpostor =
        phase != ImpostorPhase.lobby && room.impostorId == playerId;
    final revealed =
        phase == ImpostorPhase.reveal ||
        phase == ImpostorPhase.guess ||
        phase == ImpostorPhase.results;
    final myVote = room.votes[playerId];

    return room.copyWith(
      isImpostor: isImpostor,
      word: () =>
          isImpostor && phase != ImpostorPhase.results ? null : room.word,
      impostorId: () => isImpostor || revealed ? room.impostorId : null,
      votes: revealed ? room.votes : {playerId: ?myVote},
      guessChoices: phase == ImpostorPhase.guess ? room.guessChoices : const [],
    );
  }

  // ---------------------------------------------------------------- inside

  void _publish(ImpostorRoom? room) {
    _room = room;
    if (!_changes.isClosed) _changes.add(room);
  }

  void _clearTimer() {
    _stageTimer?.cancel();
    _stageTimer = null;
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
    _clearTimer();
    _publish(null);
  }

  void dispose() {
    _clearTimer();
    _changes.close();
  }
}
