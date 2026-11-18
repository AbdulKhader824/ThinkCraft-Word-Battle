import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../../models/most_likely_room.dart';
import '../../models/player.dart';
import '../game_service.dart';
import '../most_likely_questions.dart';
import '../rules/most_likely_rules.dart';
import '../rules/room_input_rules.dart';

/// Runs a Most Likely To... room on the host's phone: the questions,
/// timers, votes and scores. Moves from every phone come in through the
/// methods that take a player id; [roomFor] gives each player only what
/// they may see.
///
/// It's plain Dart, so the rules can be tested without a screen.
class MostLikelyEngine {
  MostLikelyEngine({Random? random}) : _random = random ?? Random();

  /// The host's own player id.
  static const hostId = 'host';

  final Random _random;
  final _changes = StreamController<MostLikelyRoom?>.broadcast();

  /// The whole room, every vote included. Players only ever get [roomFor].
  MostLikelyRoom? _room;
  int _nextGuestNumber = 1;

  final _usedQuestions = <String>{};

  Timer? _stageTimer;

  /// The whole room, as the host's phone knows it. Screens use [roomFor].
  MostLikelyRoom? get room => _room;

  /// Every change to the room.
  Stream<MostLikelyRoom?> get roomChanges => _changes.stream;

  // ----------------------------------------------------------------- rooms

  /// Opens a room. An online room passes the [code] the relay holds for it.
  void createRoom({
    required String hostName,
    required int avatarIndex,
    required int capacity,
    required MostLikelySettings settings,
    String? code,
  }) {
    _clearTimer();
    _usedQuestions.clear();
    _nextGuestNumber = 1;
    _publish(
      MostLikelyRoom(
        code: code ?? _newCode(),
        settings: settings,
        capacity: capacity.clamp(
          MostLikelyRoom.minPlayers,
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
    if (room.phase != MostLikelyPhase.lobby) {
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
    if (away && room.phase == MostLikelyPhase.lobby) {
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
    if (away) _afterSomeoneWent();
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
    if (room.phase != MostLikelyPhase.lobby &&
        players.length < MostLikelyRoom.minPlayers) {
      close();
      return;
    }
    _publish(
      room.copyWith(
        players: players,
        awayIds: {...room.awayIds}..remove(playerId),
        readyIds: {...room.readyIds}..remove(playerId),
        scores: {...room.scores}..remove(playerId),
        roundPoints: {...room.roundPoints}..remove(playerId),
        titles: {...room.titles}..remove(playerId),
      ),
    );
    _afterSomeoneWent();
  }

  /// The game carries on without a player who has gone.
  void _afterSomeoneWent() {
    switch (_room!.phase) {
      case MostLikelyPhase.vote:
        _checkEveryoneVoted();
      case MostLikelyPhase.results:
        _checkEveryoneReady();
      default:
        break;
    }
  }

  void setReady(String playerId, bool isReady) {
    final room = _room;
    if (room == null || room.phase != MostLikelyPhase.lobby) return;
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
    if (room.phase != MostLikelyPhase.lobby || !room.canStart) return;
    _publish(_freshGame(room).copyWith(awayIds: const {}));
    _beginQuestion(1);
  }

  /// After the last question, the host plays again with the same players.
  void newGame(String playerId) {
    final room = _room;
    if (room == null || playerId != hostId || !room.isGameOver) return;
    _publish(_freshGame(room));
    _beginQuestion(1);
  }

  MostLikelyRoom _freshGame(MostLikelyRoom room) => room.copyWith(
    questionNumber: 0,
    scores: const {},
    roundPoints: const {},
    titles: const {},
  );

  // ------------------------------------------------------------- questions

  List<String> _here(MostLikelyRoom room) => [
    for (final player in room.players)
      if (!room.awayIds.contains(player.id)) player.id,
  ];

  void _beginQuestion(int number) {
    final room = _room!;
    final pick = MostLikelyQuestions.pick(
      room.settings.topics,
      _random,
      used: _usedQuestions,
    );
    _usedQuestions.add(pick.question);
    final startsRound =
        (number - 1) % MostLikelySettings.questionsPerRound == 0;
    _enter(
      room.copyWith(
        phase: MostLikelyPhase.vote,
        questionNumber: number,
        topic: () => pick.topic,
        question: () => pick.question,
        votes: const {},
        votedIds: const {},
        voteCounts: const {},
        mostLikelyIds: const {},
        questionPoints: const {},
        roundPoints: startsRound ? const {} : null,
        readyIds: const {},
      ),
      MostLikelyRoom.voteTime,
    );
  }

  /// A secret vote for who is most likely. Players may vote for
  /// themselves, and a vote can't be changed.
  void vote(String playerId, String targetId) {
    final room = _room;
    if (room == null || room.phase != MostLikelyPhase.vote) return;
    if (!hasPlayer(playerId) || !hasPlayer(targetId)) return;
    if (room.votes.containsKey(playerId)) return;
    _publish(
      room.copyWith(
        votes: {...room.votes, playerId: targetId},
        votedIds: {...room.votedIds, playerId},
      ),
    );
    _checkEveryoneVoted();
  }

  void _checkEveryoneVoted() {
    final room = _room;
    if (room == null || room.phase != MostLikelyPhase.vote) return;
    if (_here(room).every(room.votes.containsKey)) _reveal();
  }

  void _reveal() {
    final room = _room!;
    // Votes by or for players who have left don't count.
    final votes = {
      for (final MapEntry(key: voter, value: target) in room.votes.entries)
        if (hasPlayer(voter) && hasPlayer(target)) voter: target,
    };
    final mostLikely = MostLikelyRules.mostLikely(votes);
    final points = MostLikelyRules.points(votes);
    _enter(
      room.copyWith(
        phase: MostLikelyPhase.reveal,
        votes: votes,
        voteCounts: MostLikelyRules.tally(votes),
        mostLikelyIds: mostLikely,
        questionPoints: points,
        roundPoints: MostLikelyRules.addPoints(room.roundPoints, points),
        titles: MostLikelyRules.addTitle(
          room.titles,
          mostLikely,
          room.question!,
        ),
      ),
      MostLikelyRoom.revealTime,
    );
  }

  /// The leaderboard after a round's last question.
  void _endRound() {
    _clearTimer();
    final room = _room!;
    final last = room.isFinalRound;
    _publish(
      room.copyWith(
        phase: MostLikelyPhase.results,
        scores: MostLikelyRules.addPoints(room.scores, room.roundPoints),
        readyIds: const {},
        deadline: () =>
            last ? null : clock.now().add(MostLikelyRoom.nextRoundWait),
      ),
    );
    if (!last) _stageTimer = Timer(MostLikelyRoom.nextRoundWait, _onDeadline);
  }

  /// A player pressed Next Round.
  void nextRound(String playerId) {
    final room = _room;
    if (room == null || room.phase != MostLikelyPhase.results) return;
    if (room.isFinalRound || !hasPlayer(playerId)) return;
    _publish(room.copyWith(readyIds: {...room.readyIds, playerId}));
    _checkEveryoneReady();
  }

  void _checkEveryoneReady() {
    final room = _room;
    if (room == null || room.phase != MostLikelyPhase.results) return;
    if (room.isFinalRound) return;
    if (_here(room).every(room.readyIds.contains)) {
      _beginQuestion(room.questionNumber + 1);
    }
  }

  /// Next Round waited long enough: players who didn't press it leave,
  /// except the host, and the round starts with the rest.
  void _closeNextRoundWait() {
    final room = _room!;
    final staying = [
      for (final player in room.players)
        if (player.isHost || room.readyIds.contains(player.id)) player,
    ];
    if (staying.length < MostLikelyRoom.minPlayers) {
      close();
      return;
    }
    final ids = {for (final player in staying) player.id};
    Map<String, T> keep<T>(Map<String, T> map) => {
      for (final MapEntry(:key, :value) in map.entries)
        if (ids.contains(key)) key: value,
    };
    _publish(
      room.copyWith(
        players: staying,
        awayIds: room.awayIds.intersection(ids),
        scores: keep(room.scores),
        titles: keep(room.titles),
      ),
    );
    _beginQuestion(room.questionNumber + 1);
  }

  /// Moves to [next], a new stage lasting [length].
  void _enter(MostLikelyRoom next, Duration length) {
    _clearTimer();
    _publish(next.copyWith(deadline: () => clock.now().add(length)));
    _stageTimer = Timer(length, _onDeadline);
  }

  void _onDeadline() {
    final room = _room;
    if (room == null) return;
    switch (room.phase) {
      case MostLikelyPhase.vote:
        _reveal();
      case MostLikelyPhase.reveal:
        if (room.isLastOfRound) {
          _endRound();
        } else {
          _beginQuestion(room.questionNumber + 1);
        }
      case MostLikelyPhase.results:
        if (!room.isFinalRound) _closeNextRoundWait();
      case MostLikelyPhase.lobby:
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

  /// The room as [playerId] may see it: only their own vote, and only
  /// their own points until the leaderboard.
  MostLikelyRoom? roomFor(String playerId) {
    final room = _room;
    if (room == null) return null;
    Map<String, T> mine<T extends Object>(Map<String, T> map) => {
      playerId: ?map[playerId],
    };
    return room.copyWith(
      votes: mine(room.votes),
      questionPoints: mine(room.questionPoints),
      roundPoints: room.phase == MostLikelyPhase.results
          ? room.roundPoints
          : mine(room.roundPoints),
    );
  }

  // ---------------------------------------------------------------- inside

  void _publish(MostLikelyRoom? room) {
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
