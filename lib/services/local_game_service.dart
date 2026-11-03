import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../models/answer.dart';
import '../models/answer_group.dart';
import '../models/category.dart';
import '../models/game_phase.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../models/round.dart';
import '../models/round_results.dart';
import '../models/vote.dart';
import 'bot_player.dart';
import 'game_service.dart';
import 'rules/answer_rules.dart';
import 'rules/game_rules.dart';
import 'rules/room_input_rules.dart';
import 'rules/scoring_rules.dart';
import 'rules/vote_rules.dart';

/// How long simulated players take to act.
class BotTiming {
  const BotTiming({
    this.ready = const (Duration(milliseconds: 500), Duration(seconds: 3)),
    this.hostStart = const Duration(milliseconds: 1500),
    this.pickLetter = const Duration(seconds: 2),
    this.letterReveal = const Duration(milliseconds: 1800),
    this.answer = const (Duration(seconds: 25), Duration(seconds: 80)),
    this.afterHumanSubmit = const (Duration(seconds: 1), Duration(seconds: 5)),
    this.voting = const (Duration(seconds: 1), Duration(seconds: 3)),
  });

  final (Duration, Duration) ready;
  final Duration hostStart;
  final Duration pickLetter;
  final Duration letterReveal;
  final (Duration, Duration) answer;

  /// Bots finish soon after the player submits, to avoid a long wait.
  final (Duration, Duration) afterHumanSubmit;

  /// How long bots take to vote once the player has finished.
  final (Duration, Duration) voting;
}

/// A complete game on this device, with bots as the other players.
///
/// This is the only place that knows the other players aren't real.
class LocalGameService implements GameService {
  /// [createBot] lets tests script exactly what bots answer.
  LocalGameService({
    Random? random,
    this.timing = const BotTiming(),
    BotPlayer Function(Random random)? createBot,
  }) : _random = random ?? Random(),
       _createBot = createBot ?? ((random) => BotPlayer(random: random));

  static const _localId = 'local-player';
  static const _botNames = [
    'Milo',
    'Luna',
    'Kai',
    'Nia',
    'Theo',
    'Ivy',
    'Arlo',
    'Zuri',
  ];
  static const _avatarCount = 8;

  final BotTiming timing;
  final Random _random;
  final BotPlayer Function(Random random) _createBot;
  final _changes = StreamController<Room?>.broadcast();
  final _timers = <Timer>{};
  final _botAnswerTimers = <String, Timer>{};
  final _bots = <String, BotPlayer>{};
  final _answers = <String, Map<Category, String>>{};

  // Who wrote what stays here until results, away from the published room.
  var _lockedAnswers = <Answer>[];
  var _groups = <AnswerGroup>[];
  var _votes = <Vote>[];

  Room? _room;

  @override
  Room? get room => _room;

  @override
  Stream<Room?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => _room == null ? null : _localId;

  @override
  Future<void> createRoom({
    required String playerName,
    required int playerCount,
    int avatarIndex = 0,
  }) async {
    _startSession(
      code: _generateRoomCode(),
      players: _buildPlayers(
        playerName: playerName,
        playerCount: playerCount,
        avatarIndex: avatarIndex,
        localIsHost: true,
      ),
    );
  }

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
  }) async {
    _startSession(
      code: roomCode,
      players: _buildPlayers(
        playerName: playerName,
        playerCount: 3 + _random.nextInt(4),
        avatarIndex: avatarIndex,
        localIsHost: false,
      ),
    );
  }

  @override
  Future<void> setReady(bool isReady) async {
    final room = _requirePhase(GamePhase.lobby);
    final me = room.playerById(_localId);
    if (me.isHost) throw StateError('The host is always ready.');

    _setPlayerReady(_localId, isReady);
  }

  @override
  Future<void> startRound() async {
    final room = _requirePhase(GamePhase.lobby);
    if (!room.playerById(_localId).isHost) {
      throw StateError('Only the host can start.');
    }
    if (!room.canStart) throw StateError('Not everyone is ready.');

    _beginRound();
  }

  @override
  Future<void> selectLetter(String letter) async {
    final room = _requirePhase(GamePhase.letterSelection);
    final round = room.round!;
    if (round.pickerId != _localId) {
      throw StateError('It is not your turn to pick.');
    }
    if (round.letter != null) throw StateError('The letter is already chosen.');
    if (!GameRules.letters.contains(letter)) {
      throw ArgumentError.value(letter, 'letter', 'Not a letter.');
    }
    if (room.usedLetters.contains(letter)) {
      throw StateError('That letter was already played.');
    }

    _applyLetter(letter);
  }

  @override
  Future<void> updateAnswer(Category category, String text) async {
    if (!_isAnswering || _hasSubmitted(_localId)) return;
    _answers.putIfAbsent(_localId, () => {})[category] = text;
  }

  @override
  Future<void> submitAnswers() async {
    if (!_isAnswering || _hasSubmitted(_localId)) return;

    _hurryBots();
    _markSubmitted(_localId);
  }

  @override
  Future<void> castVote(String ballotItemId, VoteChoice choice) async {
    final room = _requirePhase(GamePhase.validating);
    final round = room.round!;
    if (round.myVotes.containsKey(ballotItemId)) {
      throw StateError('You have already voted on this answer.');
    }
    final group = _groups.firstWhere((group) => group.id == ballotItemId);

    if (choice != VoteChoice.skip) {
      _votes = VoteRules.addVote(
        _votes,
        Vote(
          voterId: _localId,
          groupId: group.id,
          isValid: choice == VoteChoice.valid,
        ),
        group,
      );
    }

    final updated = round.copyWith(
      myVotes: {...round.myVotes, ballotItemId: choice},
    );
    _publish(room.copyWith(round: updated));

    if (updated.nextBallotItem == null) _scheduleBotVotes();
  }

  @override
  Future<void> playAgain() async {
    final room = _requirePhase(GamePhase.results);
    final everyLetterUsed = room.usedLetters.length == GameRules.letters.length;

    _room = room.copyWith(usedLetters: everyLetterUsed ? {} : null);
    _beginRound();
  }

  @override
  Future<void> refresh() async {
    final deadline = _room?.round?.deadline;
    if (!_isAnswering || deadline == null) return;
    if (!clock.now().isBefore(deadline)) _finishAnswering();
  }

  @override
  Future<void> leaveRoom() async {
    _clearSession();
    _publish(null);
  }

  @override
  void dispose() {
    _clearSession();
    _changes.close();
  }

  bool get _isAnswering => _room?.phase == GamePhase.answering;

  bool _hasSubmitted(String playerId) {
    return _room!.round!.submittedPlayerIds.contains(playerId);
  }

  Room _requirePhase(GamePhase phase) {
    final room = _room;
    if (room == null || room.phase != phase) {
      throw StateError('This action needs the ${phase.name} phase.');
    }
    return room;
  }

  void _publish(Room? room) {
    _room = room;
    _changes.add(room);
  }

  /// Runs [action] later, unless the session ends first.
  Timer _after(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
    return timer;
  }

  Duration _between((Duration, Duration) range) {
    final (shortest, longest) = range;
    final spread = longest.inMilliseconds - shortest.inMilliseconds;
    return shortest + Duration(milliseconds: _random.nextInt(spread + 1));
  }

  void _clearSession() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _botAnswerTimers.clear();
    _bots.clear();
    _answers.clear();
    _lockedAnswers = [];
    _groups = [];
    _votes = [];
    _room = null;
  }

  void _startSession({required String code, required List<Player> players}) {
    _clearSession();
    for (final player in players.where((player) => player.isBot)) {
      _bots[player.id] = _createBot(_random);
    }
    _publish(Room(code: code, players: players));

    for (final player in players.where((p) => p.isBot && !p.isReady)) {
      _after(_between(timing.ready), () => _setPlayerReady(player.id, true));
    }
  }

  String _generateRoomCode() {
    const characters = RoomInputRules.roomCodeCharacters;
    return List.generate(
      RoomInputRules.roomCodeLength,
      (_) => characters[_random.nextInt(characters.length)],
    ).join();
  }

  /// Builds the player list with the host first, because the host picks the
  /// first letter and picking then rotates through the list.
  List<Player> _buildPlayers({
    required String playerName,
    required int playerCount,
    required int avatarIndex,
    required bool localIsHost,
  }) {
    // The player's character comes first; bots share out the rest.
    final mine = avatarIndex.clamp(0, _avatarCount - 1);
    final avatars = List.generate(_avatarCount, (index) => index)
      ..shuffle(_random)
      ..remove(mine)
      ..insert(0, mine);
    final names =
        _botNames
            .where((name) => name.toLowerCase() != playerName.toLowerCase())
            .toList()
          ..shuffle(_random);

    final bots = [
      for (var index = 0; index < playerCount - 1; index++)
        Player(
          id: 'bot-$index',
          name: names[index],
          avatarIndex: avatars[index + 1],
          isBot: true,
          isHost: !localIsHost && index == 0,
          isReady: !localIsHost && index == 0,
        ),
    ];
    final me = Player(
      id: _localId,
      name: playerName,
      avatarIndex: avatars[0],
      isHost: localIsHost,
      isReady: localIsHost,
    );

    return localIsHost ? [me, ...bots] : [...bots, me];
  }

  void _setPlayerReady(String playerId, bool isReady) {
    final room = _room!;
    final updated = room.copyWith(
      players: [
        for (final player in room.players)
          player.id == playerId ? player.copyWith(isReady: isReady) : player,
      ],
    );
    _publish(updated);

    if (updated.host.isBot && updated.canStart) {
      _after(timing.hostStart, () {
        final current = _room;
        if (current?.phase == GamePhase.lobby && current!.canStart) {
          _beginRound();
        }
      });
    }
  }

  void _beginRound() {
    final room = _room!;
    final number = (room.round?.number ?? 0) + 1;
    final picker = room.players[(number - 1) % room.players.length];

    _publish(
      room.copyWith(
        phase: GamePhase.letterSelection,
        round: Round(number: number, pickerId: picker.id),
      ),
    );

    if (picker.isBot) {
      _after(timing.pickLetter, () => _applyLetter(_randomUnusedLetter()));
    }
  }

  String _randomUnusedLetter() {
    final used = _room!.usedLetters;
    final unused = GameRules.letters.where((l) => !used.contains(l)).toList();
    return unused[_random.nextInt(unused.length)];
  }

  void _applyLetter(String letter) {
    final room = _room!;
    _publish(
      room.copyWith(
        round: room.round!.copyWith(letter: letter),
        usedLetters: {...room.usedLetters, letter},
      ),
    );
    _after(timing.letterReveal, _beginAnswering);
  }

  void _beginAnswering() {
    final room = _room!;
    final round = room.round!;

    _answers.clear();
    _publish(
      room.copyWith(
        phase: GamePhase.answering,
        round: round.copyWith(deadline: clock.now().add(GameRules.answerTime)),
      ),
    );

    _after(GameRules.answerTime, _finishAnswering);
    for (final botId in _bots.keys) {
      _scheduleBotAnswer(botId, _between(timing.answer));
    }
  }

  void _scheduleBotAnswer(String botId, Duration delay) {
    _botAnswerTimers[botId] = _after(delay, () {
      _botAnswerTimers.remove(botId);
      _answers[botId] = _bots[botId]!.answersFor(_room!.round!.letter!);
      _markSubmitted(botId);
    });
  }

  void _hurryBots() {
    for (final botId in _botAnswerTimers.keys.toList()) {
      final timer = _botAnswerTimers[botId]!;
      timer.cancel();
      _timers.remove(timer);
      _scheduleBotAnswer(botId, _between(timing.afterHumanSubmit));
    }
  }

  void _markSubmitted(String playerId) {
    final room = _room!;
    final round = room.round!;
    final submitted = {...round.submittedPlayerIds, playerId};

    if (submitted.length == room.players.length) {
      _finishAnswering();
    } else {
      _publish(
        room.copyWith(round: round.copyWith(submittedPlayerIds: submitted)),
      );
    }
  }

  /// Locks everyone's answers and moves on. Bots that haven't finished still
  /// answer, so a player who runs out of time isn't left alone.
  void _finishAnswering() {
    final room = _room!;
    final round = room.round!;

    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _botAnswerTimers.clear();

    for (final entry in _bots.entries) {
      _answers[entry.key] ??= entry.value.answersFor(round.letter!);
    }

    _lockedAnswers = [
      for (final player in room.players)
        for (final category in Category.values)
          Answer(
            playerId: player.id,
            category: category,
            text: (_answers[player.id]?[category] ?? '').trim(),
          ),
    ];
    _groups = AnswerRules.groupAnswers(
      answers: _lockedAnswers,
      letter: round.letter!,
      playerIds: room.playerIds,
    );
    _votes = [];

    final ballot = [
      for (final group in _groups)
        if (VoteRules.canVote(group, _localId))
          BallotItem(id: group.id, category: group.category, text: group.text),
    ];

    _publish(
      room.copyWith(
        phase: GamePhase.validating,
        round: round.copyWith(
          submittedPlayerIds: room.playerIds.toSet(),
          ballot: ballot,
        ),
      ),
    );

    if (ballot.isEmpty) _scheduleBotVotes();
  }

  void _scheduleBotVotes() {
    _after(_between(timing.voting), _finishVoting);
  }

  /// Collects the bots' votes, scores the round and publishes the results.
  void _finishVoting() {
    final room = _room!;
    final round = room.round!;

    for (final group in _groups) {
      for (final MapEntry(key: botId, value: bot) in _bots.entries) {
        if (!VoteRules.canVote(group, botId)) continue;

        final isValid = bot.voteOn(group.category, round.letter!, group.text);
        if (isValid == null) continue;

        _votes = VoteRules.addVote(
          _votes,
          Vote(voterId: botId, groupId: group.id, isValid: isValid),
          group,
        );
      }
    }

    final results = ScoringRules.scoreRound(
      playerIds: room.playerIds,
      answers: _lockedAnswers,
      groups: _groups,
      votes: _votes,
    );

    _publish(
      room.copyWith(
        phase: GamePhase.results,
        round: round.copyWith(answers: _lockedAnswers, results: results),
        scores: {
          for (final id in room.playerIds)
            id:
                (room.scores[id] ?? const ScoreLine()) +
                (results.scores[id] ?? const ScoreLine()),
        },
      ),
    );
  }
}
