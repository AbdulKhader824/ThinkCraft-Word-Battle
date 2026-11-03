import 'dart:async';

import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/player.dart';
import 'package:thinkcraft_word_battle/models/player_profile.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/round.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/profile_store.dart';

const localId = 'me';

/// Keeps the profile in memory instead of on the device.
class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore([this.saved = const PlayerProfile()]);

  PlayerProfile saved;

  @override
  PlayerProfile load() => saved;

  @override
  Future<void> save(PlayerProfile profile) async => saved = profile;
}

Player fakePlayer(
  String id, {
  String? name,
  bool isHost = false,
  bool isReady = true,
}) {
  return Player(
    id: id,
    name: name ?? id,
    avatarIndex: id.length,
    isHost: isHost,
    isBot: id != localId,
    isReady: isReady,
  );
}

/// A scripted game: tests set the room directly and check what was asked.
/// Screens can't tell it apart from the real service, because they only
/// know the [GameService] interface.
class FakeGameService implements GameService {
  FakeGameService(this._room);

  final _changes = StreamController<Room?>.broadcast();
  final calls = <String>[];
  final typed = <Category, String>{};

  Room? _room;

  /// Changes the room as if the game had moved on.
  void emit(Room? room) {
    _room = room;
    _changes.add(room);
  }

  @override
  Room? get room => _room;

  @override
  Stream<Room?> get roomChanges => _changes.stream;

  @override
  String? get localPlayerId => localId;

  @override
  Future<void> createRoom({
    required String playerName,
    required int playerCount,
    int avatarIndex = 0,
  }) async => calls.add('createRoom');

  @override
  Future<void> joinRoom({
    required String playerName,
    required String roomCode,
    int avatarIndex = 0,
  }) async => calls.add('joinRoom');

  @override
  Future<void> setReady(bool isReady) async => calls.add('setReady $isReady');

  @override
  Future<void> startRound() async => calls.add('startRound');

  @override
  Future<void> selectLetter(String letter) async {
    calls.add('selectLetter $letter');
  }

  @override
  Future<void> updateAnswer(Category category, String text) async {
    typed[category] = text;
  }

  @override
  Future<void> submitAnswers() async => calls.add('submitAnswers');

  @override
  Future<void> castVote(String ballotItemId, VoteChoice choice) async {
    calls.add('castVote $ballotItemId ${choice.name}');
  }

  @override
  Future<void> playAgain() async => calls.add('playAgain');

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<void> leaveRoom() async {
    calls.add('leaveRoom');
    emit(null);
  }

  @override
  void dispose() => _changes.close();
}

Room fakeLobby({required List<Player> players}) {
  return Room(code: 'ABC234', players: players);
}

Room fakeLetterRoom({
  required String pickerId,
  String? letter,
  Set<String> usedLetters = const {},
}) {
  return Room(
    code: 'ABC234',
    phase: GamePhase.letterSelection,
    players: [
      fakePlayer(localId, name: 'Sam', isHost: true),
      fakePlayer('bot', name: 'Luna'),
    ],
    usedLetters: usedLetters,
    round: Round(number: 1, pickerId: pickerId, letter: letter),
  );
}

Room fakeVotingRoom({
  List<BallotItem> ballot = const [],
  Map<String, VoteChoice> myVotes = const {},
}) {
  return Room(
    code: 'ABC234',
    phase: GamePhase.validating,
    players: [
      fakePlayer(localId, name: 'Sam', isHost: true),
      fakePlayer('bot', name: 'Luna'),
      fakePlayer('bot2', name: 'Kai'),
    ],
    round: Round(
      number: 1,
      pickerId: localId,
      letter: 'M',
      ballot: ballot,
      myVotes: myVotes,
    ),
  );
}

/// Results for Sam, Luna and Kai, using the [scores] given by player id.
Room fakeResultsRoom({
  required Map<String, ScoreLine> scores,
  Map<String, List<AnswerLine>> lines = const {},
  int roundNumber = 1,
}) {
  final ids = [localId, 'bot', 'bot2'];
  return Room(
    code: 'ABC234',
    phase: GamePhase.results,
    players: [
      fakePlayer(localId, name: 'Sam', isHost: true),
      fakePlayer('bot', name: 'Luna'),
      fakePlayer('bot2', name: 'Kai'),
    ],
    scores: scores,
    round: Round(
      number: roundNumber,
      pickerId: localId,
      letter: 'M',
      results: RoundResults(
        scores: {for (final id in ids) id: scores[id] ?? const ScoreLine()},
        lines: {for (final id in ids) id: lines[id] ?? const []},
      ),
    ),
  );
}

Room fakeAnsweringRoom({
  required DateTime deadline,
  Set<String> submitted = const {},
}) {
  return Room(
    code: 'ABC234',
    phase: GamePhase.answering,
    players: [
      fakePlayer(localId, name: 'Sam', isHost: true),
      fakePlayer('bot', name: 'Luna'),
      fakePlayer('bot2', name: 'Kai'),
    ],
    round: Round(
      number: 1,
      pickerId: localId,
      letter: 'M',
      deadline: deadline,
      submittedPlayerIds: submitted,
    ),
  );
}
