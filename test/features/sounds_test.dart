import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/features/validation/validation_screen.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/models/player_profile.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/services/sound_service.dart';

import '../fakes.dart';
import '../helpers.dart';

const _mango = BallotItem(
  id: 'food:mango',
  category: Category.food,
  text: 'Mango',
);

const _iWin = {
  localId: ScoreLine(answerPoints: 2000),
  'bot': ScoreLine(answerPoints: 1000),
};

void main() {
  test('every sound file is bundled as a WAV file', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    for (final sound in GameSound.values) {
      final data = await rootBundle.load('assets/${sound.asset}');
      final header = String.fromCharCodes(data.buffer.asUint8List(0, 4));

      expect(header, 'RIFF', reason: sound.asset);
      expect(data.lengthInBytes, lessThan(100 * 1024), reason: sound.asset);
    }
  });

  group('buttons and tiles', () {
    testWidgets('a button pops when pressed', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(tester, sounds: sounds);
      await goToHome(tester);

      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(sounds.played, [GameSound.tap]);
    });

    testWidgets('choosing a tile blips', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(tester, sounds: sounds);
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));
      sounds.played.clear();

      await tapAndSettle(tester, find.byKey(const ValueKey('player-count-6')));
      await tapAndSettle(tester, find.byKey(const ValueKey('round-count-5')));
      await tapAndSettle(tester, find.byKey(const ValueKey('answer-time-30')));
      await tapAndSettle(tester, find.byKey(const ValueKey('category-movie')));

      expect(sounds.played, List.filled(4, GameSound.select));
    });

    testWidgets('a disabled button stays silent', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeLobby(
            players: [
              fakePlayer(localId, name: 'Sam', isHost: true),
              fakePlayer('bot', name: 'Kai', isReady: false),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Game'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(sounds.played, isEmpty);
    });
  });

  group('turning sound off', () {
    testWidgets('silences every sound', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        profiles: MemoryProfileStore(const PlayerProfile(soundOn: false)),
      );
      await goToHome(tester);

      await tapAndSettle(tester, buttonLabelled('Create Room'));
      await tapAndSettle(tester, find.byKey(const ValueKey('player-count-6')));

      expect(sounds.played, isEmpty);
    });

    testWidgets('Settings saves the sound switch', (tester) async {
      final store = MemoryProfileStore(
        const PlayerProfile(name: 'Sam', avatarIndex: 4),
      );
      await pumpGame(tester, profiles: store);
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Settings'));

      await tapAndSettle(tester, find.byKey(const ValueKey('sound-switch')));
      await tapAndSettle(tester, find.text('Save'));

      expect(store.saved.soundOn, isFalse);
      expect(store.saved.name, 'Sam', reason: 'other settings are kept');
      expect(store.saved.avatarIndex, 4);
    });

    testWidgets('saving a name keeps sound switched off', (tester) async {
      final store = MemoryProfileStore(const PlayerProfile(soundOn: false));
      await pumpGame(tester, profiles: store);
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Settings'));

      await tester.enterText(find.byType(TextFormField).first, 'Luna');
      await tapAndSettle(tester, find.text('Save'));

      expect(store.saved.name, 'Luna');
      expect(store.saved.soundOn, isFalse);
    });

    testWidgets('switching sound on plays a preview', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        profiles: MemoryProfileStore(const PlayerProfile(soundOn: false)),
      );
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Settings'));

      await tapAndSettle(tester, find.byKey(const ValueKey('sound-switch')));

      expect(sounds.played, [GameSound.select]);
    });
  });

  group('during the game', () {
    testWidgets('the Lobby pops when another player gets ready', (
      tester,
    ) async {
      final sounds = FakeSoundPlayer();
      final service = FakeGameService(
        fakeLobby(
          players: [
            fakePlayer(localId, name: 'Sam', isHost: true),
            fakePlayer('bot', name: 'Kai', isReady: false),
          ],
        ),
      );
      await pumpGame(tester, sounds: sounds, service: service);
      await tester.pumpAndSettle();
      expect(sounds.played, isEmpty);

      service.emit(
        fakeLobby(
          players: [
            fakePlayer(localId, name: 'Sam', isHost: true),
            fakePlayer('bot', name: 'Kai'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(sounds.played, [GameSound.ready]);
    });

    testWidgets('picking a letter blips, and the reveal sparkles', (
      tester,
    ) async {
      final sounds = FakeSoundPlayer();
      final service = FakeGameService(fakeLetterRoom(pickerId: localId));
      await pumpGame(tester, sounds: sounds, service: service);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byKey(const ValueKey('letter-M')));
      expect(sounds.played, [GameSound.select]);

      service.emit(fakeLetterRoom(pickerId: localId, letter: 'M'));
      await tester.pumpAndSettle();

      expect(sounds.played, [GameSound.select, GameSound.reveal]);
    });

    testWidgets('the timer ticks for each of the last 5 seconds', (
      tester,
    ) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeAnsweringRoom(
            deadline: clock.now().add(const Duration(seconds: 8)),
          ),
        ),
      );

      for (var step = 0; step < 50; step++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(sounds.played, List.filled(5, GameSound.tick));
    });

    testWidgets('no ticking once answers are locked', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeAnsweringRoom(
            deadline: clock.now().add(const Duration(seconds: 8)),
            submitted: {localId},
          ),
        ),
      );

      for (var step = 0; step < 50; step++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(sounds.played, isEmpty);
    });

    testWidgets('locking in chimes once, with no extra pop', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeAnsweringRoom(
            deadline: clock.now().add(const Duration(seconds: 60)),
            settings: GameSettings(categories: const [Category.food]),
          ),
        ),
      );
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Mango');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFrames(tester);
      await tester.tap(find.text('Lock In Answers'));
      await pumpFrames(tester);

      expect(sounds.played, [GameSound.lock]);
    });

    for (final (label, sound) in [
      ('Correct', GameSound.valid),
      ('Incorrect', GameSound.invalid),
      ('Not sure? Skip this one', GameSound.tap),
    ]) {
      testWidgets('voting "$label" plays its own sound once', (tester) async {
        final sounds = FakeSoundPlayer();
        await pumpGame(
          tester,
          sounds: sounds,
          service: FakeGameService(fakeVotingRoom(ballot: const [_mango])),
        );
        await tester.pumpAndSettle();
        await tester.pump(ValidationScreen.tapGuard);

        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(sounds.played, [sound]);
      });
    }

    testWidgets('results play a fanfare', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeResultsRoom(scores: _iWin, roundNumber: 1, rounds: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(sounds.played, [GameSound.results]);
    });

    testWidgets('winning the game plays the big fanfare', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(fakeResultsRoom(scores: _iWin)),
      );
      await tester.pumpAndSettle();

      expect(sounds.played, [GameSound.win]);
    });

    testWidgets('losing the game plays the normal fanfare', (tester) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(
          fakeResultsRoom(
            scores: const {
              localId: ScoreLine(answerPoints: 500),
              'bot': ScoreLine(answerPoints: 2000),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sounds.played, [GameSound.results]);
    });

    testWidgets('the fanfare plays once, even when the screen updates', (
      tester,
    ) async {
      final sounds = FakeSoundPlayer();
      await pumpGame(
        tester,
        sounds: sounds,
        service: FakeGameService(fakeResultsRoom(scores: _iWin)),
      );
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('Sam (you)'));

      expect(sounds.played, [GameSound.win]);
    });
  });
}
