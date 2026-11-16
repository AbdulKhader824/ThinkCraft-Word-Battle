import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../models/answer.dart';
import '../models/answer_group.dart';
import '../models/category.dart';
import '../models/game_phase.dart';
import '../models/game_settings.dart';
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
import 'rules/word_check.dart';

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
    this.nextRound = const (Duration(seconds: 1), Duration(seconds: 4)),
  });

  final (Duration, Duration) ready;
  final Duration hostStart;
  final Duration pickLetter;
  final Duration letterReveal;

  /// How long bots take to answer in a standard 90-second round. Shorter
  /// rounds scale this down, so bots still usually beat the timer.
  final (Duration, Duration) answer;

  /// Bots finish soon after the players submit, to avoid a long wait.
  final (Duration, Duration) afterHumanSubmit;

  /// How long bots take to vote once the players have finished.
  final (Duration, Duration) voting;

  /// How long bots take to press Next Round on the results.
  final (Duration, Duration) nextRound;
}

/// A complete game on this device: the rules, the timers, and any bots.
///
/// In practice mode the other players are bots. In a nearby room this is
/// the host's copy of the game, and other phones play through it: the
/// methods ending in `For` act for one of those players, and [roomFor]
/// gives the room as that player may see it.
class LocalGameService implements GameService {
  /// [createBot] lets tests script exactly what bots answer.
  LocalGameService({
    Random? random,
    this.timing = const BotTiming(),
    BotPlayer Function(Random random)? createBot,
    this._wordList,
    this.loadWords,
  }) : _random = random ?? Random(),
       _createBot = createBot ?? ((random) => BotPlayer(random: random));

  /// Loads the word list for checking answers. It is big, so it loads the
  /// first time a room opens, while players are in the lobby.
  final Future<WordList> Function()? loadWords;
  WordList? _wordList;
  Future<void>? _loadingWords;

  void _startLoadingWords() {
    final load = loadWords;
    if (_wordList != null || _loadingWords != null || load == null) return;
    _loadingWords = load().then<void>(
      (words) => _wordList = words,
      // Without a list, every answer is simply voted on.
      onError: (Object _) => _loadingWords = null,
    );
  }

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

  /// The most players a room can hold.
  static const maxPlayers = 8;

  /// How long a player on another phone has to pick the letter before one
  /// is picked for them.
  static const guestPickTime = Duration(seconds: 30);

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

  /// Each real player's own ballot and choices. Players never see anyone
  /// else's.
  final _ballots = <String, List<BallotItem>>{};
  final _choices = <String, Map<String, VoteChoice>>{};

  /// Players on other phones who have lost their connection. The game
  /// doesn't wait for them.
  final _away = <String>{};

  var _nextGuestNumber = 1;
  var _votingClosing = false;

  /// The room as this phone's player sees it.
  Room? _room;

  /// Ends the wait for Next Round. Cancelled if everyone is ready sooner.
  Timer? _nextRoundWait;

  /// Closes voting when its time is up. Cancelled if everyone finishes
  /// sooner.
  Timer? _voteTimer;

  @override
  Room? get room => _room;

  @override
  Stream<Room?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => _room == null ? null : _localId;

  /// The real players: this phone's player and any on other phones.
  Iterable<String> get _humanIds sync* {
    for (final player in _room?.players ?? const <Player>[]) {
      if (!player.isBot) yield player.id;
    }
  }

  /// The room as [playerId] may see it: with their own ballot and votes.
  Room? roomFor(String playerId) {
    final room = _room;
    final round = room?.round;
    if (room == null || round == null) return room;
    return room.copyWith(
      round: round.copyWith(
        ballot: _ballots[playerId] ?? const [],
        myVotes: _choices[playerId] ?? const {},
        votedPlayerIds: room.phase == GamePhase.validating
            ? {
                for (final player in room.players)
                  if (!_isStillVoting(player.id)) player.id,
              }
            : const {},
      ),
    );
  }

  /// True while voting waits for [playerId]: a real player who is here
  /// and has answers left on their ballot.
  bool _isStillVoting(String playerId) {
    if (_away.contains(playerId) || !_ballots.containsKey(playerId)) {
      return false;
    }
    final choices = _choices[playerId] ?? const {};
    return _ballots[playerId]!.any((item) => !choices.containsKey(item.id));
  }

  @override
  Future<void> createRoom({
    required String playerName,
    required int playerCount,
    int avatarIndex = 0,
    GameSettings? settings,
    RoomMode mode = RoomMode.practice,
    bool fillWithBots = false,
    String? code,
  }) async {
    _startLoadingWords();
    // Nearby and online rooms are for friends; only the connection differs.
    final withFriends = mode != RoomMode.practice;
    _startSession(
      // An online room uses the code the relay holds for it.
      code: code ?? _generateRoomCode(),
      settings: settings ?? GameSettings.standard,
      mode: mode,
      // In a nearby room, the count is the room's size: it starts with
      // just the host, friends join it, and bots may fill the rest.
      capacity: playerCount.clamp(2, maxPlayers),
      fillWithBots: withFriends && fillWithBots,
      players: _buildPlayers(
        playerName: playerName,
        playerCount: withFriends ? 1 : playerCount,
        avatarIndex: avatarIndex,
        localIsHost: true,
      ),
    );
  }

  /// Joins a practice room run by a bot host. The app now joins real rooms
  /// instead, but this stays for practising the guest's side in tests.
  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
    String? hostAddress,
    bool online = false,
  }) async {
    _startLoadingWords();
    // A guest plays by the host's settings. The bot host uses the standard.
    final players = 3 + _random.nextInt(4);
    _startSession(
      code: roomCode,
      settings: GameSettings.standard,
      mode: RoomMode.practice,
      capacity: players,
      players: _buildPlayers(
        playerName: playerName,
        playerCount: players,
        avatarIndex: avatarIndex,
        localIsHost: false,
      ),
    );
  }

  // ------------------------------------------------- players on other phones

  /// Adds a player from another phone to the lobby, and returns their id.
  String addPlayer({required String name, required int avatarIndex}) {
    final room = _room;
    if (room == null) throw const JoinRefused('That room has closed.');
    if (room.phase != GamePhase.lobby) {
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
          Player(
            id: id,
            name: name,
            avatarIndex: avatarIndex.clamp(0, _avatarCount - 1),
          ),
        ],
      ),
    );
    return id;
  }

  /// True while [playerId] is still in the room.
  bool hasPlayer(String playerId) {
    return _room?.players.any((player) => player.id == playerId) ?? false;
  }

  /// A player's phone lost its connection, or came back.
  void setAway(String playerId, {required bool away}) {
    final room = _room;
    if (room == null || !hasPlayer(playerId)) return;

    if (away && room.phase == GamePhase.lobby) {
      // Nothing has started, so they simply leave the lobby.
      removePlayer(playerId);
      return;
    }
    if (away) {
      _away.add(playerId);
    } else {
      _away.remove(playerId);
    }
    if (room.phase == GamePhase.validating) {
      // Everyone sees who voting is waiting for; it doesn't wait for
      // someone who isn't there.
      _publish(room);
      _checkVotingDone();
    }
  }

  /// Takes a player out of the room. In the middle of a round they are
  /// only marked away, and leave properly before the next one.
  void removePlayer(String playerId) {
    final room = _room;
    if (room == null || !hasPlayer(playerId)) return;
    if (room.phase != GamePhase.lobby) {
      setAway(playerId, away: true);
      return;
    }
    _publish(
      room.copyWith(
        players: [
          for (final player in room.players)
            if (player.id != playerId) player,
        ],
      ),
    );
  }

  // ---------------------------------------------------- the player's actions

  @override
  Future<void> setReady(bool isReady) async => setReadyFor(_localId, isReady);

  void setReadyFor(String playerId, bool isReady) {
    final room = _requirePhase(GamePhase.lobby);
    final player = room.playerById(playerId);
    if (player.isHost) throw StateError('The host is always ready.');

    _setPlayerReady(playerId, isReady);
  }

  @override
  Future<void> startRound() async {
    final room = _requirePhase(GamePhase.lobby);
    if (!room.playerById(_localId).isHost) {
      throw StateError('Only the host can start.');
    }
    if (!room.canStart) throw StateError('Not everyone is ready.');

    _fillEmptySeats();
    _beginRound();
  }

  @override
  Future<void> selectLetter(String letter) async {
    selectLetterFor(_localId, letter);
  }

  void selectLetterFor(String playerId, String letter) {
    final room = _requirePhase(GamePhase.letterSelection);
    final round = room.round!;
    if (round.pickerId != playerId) {
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
    updateAnswerFor(_localId, category, text);
  }

  void updateAnswerFor(String playerId, Category category, String text) {
    if (!_isAnswering || _hasSubmitted(playerId)) return;
    _answers.putIfAbsent(playerId, () => {})[category] = text;
  }

  @override
  Future<void> submitAnswers() async => submitAnswersFor(_localId);

  void submitAnswersFor(String playerId) {
    if (!_isAnswering || _hasSubmitted(playerId)) return;

    _markSubmitted(playerId);
    // Once every real player is done, the bots hurry up too.
    final room = _room;
    if (room != null &&
        room.phase == GamePhase.answering &&
        _humanIds.every(_hasSubmitted)) {
      _hurryBots();
    }
  }

  @override
  Future<void> castVote(String ballotItemId, VoteChoice choice) async {
    castVoteFor(_localId, ballotItemId, choice);
  }

  void castVoteFor(String playerId, String ballotItemId, VoteChoice choice) {
    final room = _requirePhase(GamePhase.validating);
    final ballot = _ballots[playerId] ?? const [];
    final choices = _choices.putIfAbsent(playerId, () => {});
    if (choices.containsKey(ballotItemId)) {
      throw StateError('You have already voted on this answer.');
    }
    if (!ballot.any((item) => item.id == ballotItemId)) {
      throw StateError('That answer is not on your ballot.');
    }
    final group = _groups.firstWhere((group) => group.id == ballotItemId);

    if (choice != VoteChoice.skip) {
      _votes = VoteRules.addVote(
        _votes,
        Vote(
          voterId: playerId,
          groupId: group.id,
          isValid: choice == VoteChoice.valid,
        ),
        group,
      );
    }
    choices[ballotItemId] = choice;

    _publish(room);
    _checkVotingDone();
  }

  @override
  Future<void> nextRound() async => nextRoundFor(_localId);

  void nextRoundFor(String playerId) {
    final room = _requirePhase(GamePhase.results);
    if (room.isFinalRound) throw StateError('That was the final round.');

    _markNextRoundReady(playerId);
  }

  @override
  Future<void> newGame() async {
    final room = _requirePhase(GamePhase.results);

    // A fresh room keeps the code, players and settings, and drops the rest.
    _room = Room(
      code: room.code,
      players: [
        for (final player in room.players)
          if (!_away.contains(player.id)) player,
      ],
      settings: room.settings,
      mode: room.mode,
    );
    _away.clear();
    _beginRound();
  }

  @override
  Future<void> refresh() async {
    final round = _room?.round;
    final nextRoundDeadline = round?.nextRoundDeadline;
    if (_room?.phase == GamePhase.results && nextRoundDeadline != null) {
      if (!clock.now().isBefore(nextRoundDeadline)) _closeNextRoundWait();
      return;
    }

    final voteDeadline = round?.voteDeadline;
    if (_room?.phase == GamePhase.validating && voteDeadline != null) {
      if (!clock.now().isBefore(voteDeadline)) _closeVoting();
      return;
    }

    final deadline = round?.deadline;
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

  // ---------------------------------------------------------------- inside

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

  /// Publishes [room], showing this phone's player their own ballot.
  void _publish(Room? room) {
    _room = room;
    final mine = roomFor(_localId);
    _room = mine;
    _changes.add(mine);
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
    _nextRoundWait = null;
    _voteTimer = null;
    _botAnswerTimers.clear();
    _bots.clear();
    _answers.clear();
    _lockedAnswers = [];
    _groups = [];
    _votes = [];
    _ballots.clear();
    _choices.clear();
    _away.clear();
    _nextGuestNumber = 1;
    _votingClosing = false;
    _room = null;
  }

  void _startSession({
    required String code,
    required GameSettings settings,
    required RoomMode mode,
    required int capacity,
    bool fillWithBots = false,
    required List<Player> players,
  }) {
    _clearSession();
    for (final player in players.where((player) => player.isBot)) {
      _bots[player.id] = _createBot(_random);
    }
    _publish(
      Room(
        code: code,
        players: players,
        settings: settings,
        mode: mode,
        capacity: capacity,
        fillWithBots: fillWithBots,
      ),
    );

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

  /// Gives a nearby room's empty seats to bots, if the host asked for
  /// them. Bots take names and characters nobody is using.
  void _fillEmptySeats() {
    final room = _room!;
    final empty = room.emptySeats;
    if (!room.fillWithBots || empty == 0) return;

    final takenNames = {for (final p in room.players) p.name.toLowerCase()};
    final names =
        _botNames
            .where((name) => !takenNames.contains(name.toLowerCase()))
            .toList()
          ..shuffle(_random);
    final takenAvatars = {for (final p in room.players) p.avatarIndex};
    final avatars = [
      for (var index = 0; index < _avatarCount; index++)
        if (!takenAvatars.contains(index)) index,
    ]..shuffle(_random);
    if (avatars.isEmpty) avatars.add(0);

    final bots = [
      for (var index = 0; index < empty; index++)
        Player(
          id: 'bot-$index',
          name: names[index % names.length],
          avatarIndex: avatars[index % avatars.length],
          isBot: true,
          isReady: true,
        ),
    ];
    for (final bot in bots) {
      _bots[bot.id] = _createBot(_random);
    }
    _room = room.copyWith(players: [...room.players, ...bots]);
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
    _nextRoundWait?.cancel();
    _nextRoundWait = null;
    _voteTimer?.cancel();
    _voteTimer = null;
    _ballots.clear();
    _choices.clear();
    _votingClosing = false;
    final room = _room!;
    final number = (room.round?.number ?? 0) + 1;
    final picker = room.players[(number - 1) % room.players.length];

    _publish(
      room.copyWith(
        phase: GamePhase.letterSelection,
        round: Round(number: number, pickerId: picker.id),
      ),
    );

    if (picker.isBot || _away.contains(picker.id)) {
      // A picker who has lost their connection can't pick either, so the
      // letter is chosen for them.
      _after(timing.pickLetter, () => _applyLetter(_randomUnusedLetter()));
    } else if (picker.id != _localId) {
      // A player on another phone who never picks mustn't stop the game.
      _after(guestPickTime, () => _applyLetter(_randomUnusedLetter()));
    }
  }

  String _randomUnusedLetter() {
    final used = _room!.usedLetters;
    final unused = GameRules.letters.where((l) => !used.contains(l)).toList();
    return unused[_random.nextInt(unused.length)];
  }

  void _applyLetter(String letter) {
    final room = _room;
    if (room == null || room.phase != GamePhase.letterSelection) return;
    if (room.round!.letter != null) return;
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

    final answerTime = room.settings.answerTime;
    // Bot speeds are set for the standard 90 seconds, so shorter rounds
    // make them hurry by the same amount.
    final botSpeed =
        answerTime.inMilliseconds / GameRules.answerTime.inMilliseconds;

    _answers.clear();
    _publish(
      room.copyWith(
        phase: GamePhase.answering,
        round: round.copyWith(deadline: clock.now().add(answerTime)),
      ),
    );

    _after(answerTime, _finishAnswering);
    for (final botId in _bots.keys) {
      _scheduleBotAnswer(botId, _between(timing.answer) * botSpeed);
    }
  }

  void _scheduleBotAnswer(String botId, Duration delay) {
    _botAnswerTimers[botId] = _after(delay, () {
      _botAnswerTimers.remove(botId);
      final room = _room!;
      _answers[botId] = _bots[botId]!.answersFor(
        room.round!.letter!,
        room.settings.categories,
        room.settings.botLevel,
        _wordList,
      );
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
    final room = _room;
    if (room == null || room.phase != GamePhase.answering) return;
    final round = room.round!;

    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _botAnswerTimers.clear();

    for (final entry in _bots.entries) {
      _answers[entry.key] ??= entry.value.answersFor(
        round.letter!,
        room.settings.categories,
        room.settings.botLevel,
        _wordList,
      );
    }

    _lockedAnswers = [
      for (final player in room.players)
        for (final category in room.settings.categories)
          Answer(
            playerId: player.id,
            category: category,
            text: (_answers[player.id]?[category] ?? '').trim(),
          ),
    ];
    _groups = WordCheck.apply(
      AnswerRules.groupAnswers(
        answers: _lockedAnswers,
        letter: round.letter!,
        playerIds: room.playerIds,
      ),
      _wordList,
      room.settings.answerCheck,
    );
    _votes = [];

    // Every real player gets their own ballot, without their own answers.
    _ballots.clear();
    _choices.clear();
    for (final playerId in _humanIds) {
      _ballots[playerId] = [
        for (final group in _groups)
          if (VoteRules.canVote(group, playerId))
            BallotItem(
              id: group.id,
              category: group.category,
              text: group.text,
            ),
      ];
    }

    // One timer for the whole ballot, long enough for the biggest one.
    final cards = _ballots.values.fold(
      0,
      (most, ballot) => ballot.length > most ? ballot.length : most,
    );
    final voteTime = GameRules.voteTimeFor(cards);

    _publish(
      room.copyWith(
        phase: GamePhase.validating,
        round: round.copyWith(
          submittedPlayerIds: room.playerIds.toSet(),
          voteDeadline: cards == 0 ? null : clock.now().add(voteTime),
          voteTime: cards == 0 ? null : voteTime,
        ),
      ),
    );

    if (cards > 0) _voteTimer = _after(voteTime, _closeVoting);
    _checkVotingDone();
  }

  /// Once every real player who is still here has finished their ballot,
  /// the bots vote and the round is scored.
  void _checkVotingDone() {
    if (_votingClosing || _room?.phase != GamePhase.validating) return;

    if (_humanIds.any(_isStillVoting)) return;

    _votingClosing = true;
    _after(_between(timing.voting), _finishVoting);
  }

  /// Voting time is up: answers nobody voted on count as skipped, and the
  /// round is scored straight away.
  void _closeVoting() {
    if (_votingClosing || _room?.phase != GamePhase.validating) return;

    for (final MapEntry(key: playerId, value: ballot) in _ballots.entries) {
      final choices = _choices.putIfAbsent(playerId, () => {});
      for (final item in ballot) {
        choices.putIfAbsent(item.id, () => VoteChoice.skip);
      }
    }
    _votingClosing = true;
    _finishVoting();
  }

  /// Collects the bots' votes, scores the round and publishes the results.
  void _finishVoting() {
    final room = _room;
    if (room == null || room.phase != GamePhase.validating) return;
    final round = room.round!;
    _voteTimer?.cancel();
    _voteTimer = null;

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

    // After the final round there's no next round to wait for.
    final waitUntil = room.isFinalRound
        ? null
        : clock.now().add(GameRules.nextRoundWait);

    _publish(
      room.copyWith(
        phase: GamePhase.results,
        round: round.copyWith(
          answers: _lockedAnswers,
          results: results,
          nextRoundDeadline: waitUntil,
        ),
        scores: {
          for (final id in room.playerIds)
            id:
                (room.scores[id] ?? const ScoreLine()) +
                (results.scores[id] ?? const ScoreLine()),
        },
      ),
    );

    if (waitUntil == null) return;
    _nextRoundWait = _after(GameRules.nextRoundWait, _closeNextRoundWait);
    for (final botId in _bots.keys) {
      _after(_between(timing.nextRound), () => _markNextRoundReady(botId));
    }
  }

  /// Records that [playerId] pressed Next Round, and starts the round once
  /// everyone has.
  void _markNextRoundReady(String playerId) {
    final room = _room;
    final round = room?.round;
    if (room == null || round == null || room.phase != GamePhase.results) {
      return;
    }
    if (round.nextRoundReadyIds.contains(playerId)) return;

    final ready = {...round.nextRoundReadyIds, playerId};
    if (room.playerIds.every(ready.contains)) {
      _beginRound();
    } else {
      _publish(room.copyWith(round: round.copyWith(nextRoundReadyIds: ready)));
    }
  }

  /// The wait is over: the players who are ready carry on, and the rest
  /// leave the room. A game needs at least 2 players, so with fewer the
  /// room closes.
  void _closeNextRoundWait() {
    final room = _room;
    if (room == null || room.phase != GamePhase.results) return;
    final ready = room.round!.nextRoundReadyIds;

    final staying = room.players.where((p) => ready.contains(p.id)).toList();
    if (!ready.contains(_localId) || staying.length < 2) {
      _clearSession();
      _publish(null);
      return;
    }

    // If the host left, the first player still here takes over.
    final hasHost = staying.any((player) => player.isHost);
    final players = [
      for (final (index, player) in staying.indexed)
        hasHost ? player : player.copyWith(isHost: index == 0),
    ];
    _bots.removeWhere((id, _) => !ready.contains(id));
    _away.removeWhere((id) => !ready.contains(id));

    _room = room.copyWith(
      players: players,
      scores: {
        for (final entry in room.scores.entries)
          if (ready.contains(entry.key)) entry.key: entry.value,
      },
    );
    _beginRound();
  }
}
