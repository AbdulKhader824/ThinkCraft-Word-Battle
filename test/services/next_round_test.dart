import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';
import 'package:thinkcraft_word_battle/services/local_game_service.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

/// Bots that take [nextRound] to press Next Round.
LocalGameService _service({
  (Duration, Duration) nextRound = const (
    Duration(seconds: 1),
    Duration(seconds: 4),
  ),
}) {
  return LocalGameService(
    random: Random(3),
    timing: BotTiming(nextRound: nextRound),
  );
}

/// Plays one whole round as host and waits on the results.
void _playToResults(
  FakeAsync time,
  LocalGameService service, {
  int playerCount = 4,
  int rounds = 3,
}) {
  const timing = BotTiming();
  service.createRoom(
    playerName: 'Sam',
    playerCount: playerCount,
    settings: GameSettings(rounds: rounds),
  );
  time.elapse(timing.ready.$2);
  service.startRound();
  service.selectLetter('M');
  time.elapse(timing.letterReveal);
  time.elapse(GameRules.answerTime);
  while (true) {
    final item = service.room!.round!.nextBallotItem;
    if (item == null) break;
    service.skipFor(item.id);
  }
  time.elapse(timing.voting.$2);
}

extension on LocalGameService {
  void skipFor(String id) => castVote(id, VoteChoice.skip);
}

Room _room(LocalGameService service) => service.room!;

void main() {
  test('the results wait 60 seconds for Next Round', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service);

      final round = _room(service).round!;
      expect(_room(service).phase, GamePhase.results);
      // The results came a moment before the test stopped waiting.
      final left = round.nextRoundDeadline!.difference(clock.now());
      expect(left, lessThanOrEqualTo(GameRules.nextRoundWait));
      expect(left, greaterThan(const Duration(seconds: 55)));
      expect(round.nextRoundReadyIds, isEmpty);
      service.dispose();
    });
  });

  test('bots press Next Round, but the round waits for the player', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service);

      time.elapse(const Duration(seconds: 4));

      final room = _room(service);
      expect(room.phase, GamePhase.results);
      expect(room.round!.nextRoundReadyIds, {
        for (final player in room.players)
          if (player.isBot) player.id,
      });
      service.dispose();
    });
  });

  test('the next round starts as soon as everyone is ready', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service);
      time.elapse(const Duration(seconds: 4));

      service.nextRound();

      expect(_room(service).phase, GamePhase.letterSelection);
      expect(_room(service).round!.number, 2);
      expect(_room(service).players, hasLength(4));
      service.dispose();
    });
  });

  test('pressing Next Round twice counts once', () {
    fakeAsync((time) {
      final service = _service(
        nextRound: const (Duration(seconds: 30), Duration(seconds: 30)),
      );
      _playToResults(time, service);

      service.nextRound();
      service.nextRound();

      expect(_room(service).round!.nextRoundReadyIds, {service.localPlayerId});
      service.dispose();
    });
  });

  test('a player who never presses Next Round leaves the room', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service);

      time.elapse(GameRules.nextRoundWait);

      expect(service.room, isNull);
      service.dispose();
    });
  });

  test('players not ready in time are left behind', () {
    fakeAsync((time) {
      // Some bots answer within the 60 seconds and some don't.
      final service = _service(
        nextRound: const (Duration(seconds: 1), Duration(seconds: 120)),
      );
      _playToResults(time, service, playerCount: 8);
      service.nextRound();

      time.elapse(GameRules.nextRoundWait);

      final room = _room(service);
      expect(room.phase, GamePhase.letterSelection);
      expect(room.round!.number, 2);
      expect(room.players.length, inInclusiveRange(2, 7));
      expect(room.playerIds, contains(service.localPlayerId));
      expect(room.scores.keys.toSet(), room.playerIds.toSet());
      service.dispose();
    });
  });

  test('with nobody else ready, the room closes', () {
    fakeAsync((time) {
      final service = _service(
        nextRound: const (Duration(seconds: 90), Duration(seconds: 90)),
      );
      _playToResults(time, service);
      service.nextRound();

      time.elapse(GameRules.nextRoundWait);

      expect(service.room, isNull);
      service.dispose();
    });
  });

  test('after the final round there is nothing to wait for', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service, rounds: 1);

      expect(_room(service).round!.nextRoundDeadline, isNull);
      time.elapse(GameRules.nextRoundWait * 2);
      expect(_room(service).phase, GamePhase.results);
      service.dispose();
    });
  });

  test('returning to the app after the wait applies it', () {
    fakeAsync((time) {
      final service = _service();
      _playToResults(time, service);

      // The phone was asleep, so the timer didn't fire, but the clock moved.
      withClock(Clock.fixed(clock.now().add(const Duration(minutes: 2))), () {
        service.refresh();
      });

      expect(service.room, isNull);
      service.dispose();
    });
  });
}
