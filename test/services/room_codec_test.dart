import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/answer.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/player.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/round.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/nearby/room_codec.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';

/// Sends a room through JSON text and back, as between two phones.
Room _roundTrip(Room room) {
  final text = jsonEncode(RoomCodec.encode(room));
  return RoomCodec.decode(jsonDecode(text) as Map<String, Object?>);
}

void main() {
  final now = DateTime(2026, 11, 5, 10);

  test('a room arrives the same on the other phone', () {
    withClock(Clock.fixed(now), () {
      final room = Room(
        code: 'K7PQ2M',
        mode: RoomMode.nearby,
        capacity: 6,
        fillWithBots: true,
        phase: GamePhase.results,
        settings: GameSettings(
          rounds: 5,
          answerSeconds: 60,
          categories: const [Category.food, Category.animal],
          answerCheck: AnswerCheck.auto,
          botLevel: BotLevel.hard,
        ),
        players: const [
          Player(id: 'a', name: 'Sam', avatarIndex: 1, isHost: true),
          Player(id: 'b', name: 'Luna', avatarIndex: 4, isReady: true),
        ],
        usedLetters: const {'M', 'B'},
        scores: const {'a': ScoreLine(answerPoints: 1333, validationPoints: 1)},
        round: Round(
          number: 2,
          pickerId: 'b',
          letter: 'B',
          submittedPlayerIds: const {'a', 'b'},
          answers: const [
            Answer(playerId: 'a', category: Category.food, text: 'Banana'),
          ],
          ballot: const [
            BallotItem(id: 'g1', category: Category.animal, text: 'Bear'),
          ],
          myVotes: const {'g1': VoteChoice.valid},
          results: RoundResults(
            scores: const {'a': ScoreLine(answerPoints: 1000)},
            lines: const {
              'a': [
                AnswerLine(
                  category: Category.food,
                  text: 'Banana',
                  verdict: AnswerVerdict.valid,
                  points: 1000,
                  byWordList: true,
                  noVotes: true,
                ),
                AnswerLine(
                  category: Category.animal,
                  text: '',
                  verdict: null,
                  points: 0,
                ),
              ],
            },
          ),
          nextRoundReadyIds: const {'b'},
        ),
      );

      final copy = _roundTrip(room);

      expect(copy.code, 'K7PQ2M');
      expect(copy.mode, RoomMode.nearby);
      expect(copy.capacity, 6);
      expect(copy.fillWithBots, isTrue);
      expect(copy.phase, GamePhase.results);
      expect(copy.settings.rounds, 5);
      expect(copy.settings.categories, [Category.animal, Category.food]);
      expect(copy.settings.answerCheck, AnswerCheck.auto);
      expect(copy.settings.botLevel, BotLevel.hard);
      expect(copy.round!.results!.lines['a']!.first.byWordList, isTrue);
      expect(copy.round!.results!.lines['a']!.first.noVotes, isTrue);
      expect(copy.players.map((p) => p.name), ['Sam', 'Luna']);
      expect(copy.host.id, 'a');
      expect(copy.players.last.isReady, isTrue);
      expect(copy.usedLetters, {'M', 'B'});
      expect(copy.scores['a']!.total, 1433);
      final round = copy.round!;
      expect(round.letter, 'B');
      expect(round.answers.single.text, 'Banana');
      expect(round.ballot.single.text, 'Bear');
      expect(round.myVotes['g1'], VoteChoice.valid);
      expect(round.results!.lines['a']!.last.verdict, isNull);
      expect(round.nextRoundReadyIds, {'b'});
    });
  });

  test('timers are sent as time left, so phone clocks needn\'t match', () {
    final room = Room(
      code: 'K7PQ2M',
      phase: GamePhase.answering,
      players: const [Player(id: 'a', name: 'Sam', avatarIndex: 0)],
      round: Round(
        number: 1,
        pickerId: 'a',
        letter: 'M',
        deadline: now.add(const Duration(seconds: 42)),
      ),
    );

    final sent = withClock(Clock.fixed(now), () => RoomCodec.encode(room));
    // The guest's clock is five minutes off.
    final guestNow = now.add(const Duration(minutes: 5));
    final received = withClock(
      Clock.fixed(guestNow),
      () => RoomCodec.decode(
        jsonDecode(jsonEncode(sent)) as Map<String, Object?>,
      ),
    );

    expect(
      received.round!.deadline!.difference(guestNow),
      const Duration(seconds: 42),
    );
  });

  test('a room from an older app version is voted on', () {
    final json = RoomCodec.encode(Room(code: 'K7PQ2M', players: const []));
    (json['settings']! as Map<String, Object?>)
      ..remove('answerCheck')
      ..remove('botLevel');

    final copy = RoomCodec.decode(json);

    expect(copy.settings.answerCheck, AnswerCheck.vote);
    expect(copy.settings.botLevel, BotLevel.medium);
  });

  test('the voting timer and who has voted travel too', () {
    final room = Room(
      code: 'K7PQ2M',
      phase: GamePhase.validating,
      players: const [Player(id: 'a', name: 'Sam', avatarIndex: 0)],
      round: Round(
        number: 1,
        pickerId: 'a',
        letter: 'M',
        voteDeadline: now.add(const Duration(seconds: 9)),
        voteTime: const Duration(seconds: 12),
        votedPlayerIds: const {'a'},
      ),
    );

    final copy = withClock(Clock.fixed(now), () => _roundTrip(room));

    expect(copy.round!.voteDeadline, now.add(const Duration(seconds: 9)));
    expect(copy.round!.voteTime, const Duration(seconds: 12));
    expect(copy.round!.votedPlayerIds, {'a'});
  });

  test('room announcements are read back, and strangers ignored', () {
    const info = NearbyRoomInfo(
      code: 'K7PQ2M',
      hostName: 'Ammu',
      hostAvatar: 2,
      playerCount: 3,
      capacity: 4,
      address: '',
      port: 47530,
    );

    final heard = NearbyRoomInfo.fromBeacon(
      jsonDecode(jsonEncode(info.toBeacon())),
      '192.168.43.1',
    );

    expect(heard!.code, 'K7PQ2M');
    expect(heard.hostName, 'Ammu');
    expect(heard.address, '192.168.43.1');
    expect(heard.capacity, 4);
    expect(heard.isFull, isFalse);
    expect(NearbyRoomInfo.fromBeacon({'app': 'other'}, '1.2.3.4'), isNull);
    expect(NearbyRoomInfo.fromBeacon('not a map', '1.2.3.4'), isNull);
  });
}
