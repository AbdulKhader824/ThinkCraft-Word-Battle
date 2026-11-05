import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/app.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';
import 'package:thinkcraft_word_battle/models/player.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/models/round.dart';
import 'package:thinkcraft_word_battle/models/round_results.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

import '../fakes.dart';
import '../helpers.dart';

/// Phone widths from a small Android phone up to a large one, with heights
/// to match.
const _phones = [
  Size(320, 568),
  Size(360, 740),
  Size(412, 915),
  Size(430, 932),
];

/// Normal text, plus the largest system text size, which the app caps at
/// [ThinkCraftApp.maxTextScale].
const _textScales = [1.0, 2.0];

final _longNames = [
  'Abdul Khader',
  'Maximilianus',
  'Wwwwwwwwwwww',
  'Luna',
  'Kai',
  'Nia',
  'Theo',
  'Ivy',
];

List<Player> _eightPlayers() {
  return [
    for (final (index, name) in _longNames.indexed)
      Player(
        id: index == 0 ? localId : 'bot$index',
        name: name,
        avatarIndex: index,
        isHost: index == 0,
        isBot: index != 0,
        isReady: index.isEven,
      ),
  ];
}

const _longAnswers = [
  AnswerLine(
    category: Category.animal,
    text: 'Madagascan Hissing Cockroach',
    verdict: AnswerVerdict.valid,
    points: 1000,
  ),
  AnswerLine(
    category: Category.place,
    text: 'Mexico City',
    verdict: AnswerVerdict.invalid,
    points: 0,
  ),
  AnswerLine(
    category: Category.person,
    text: 'Michael',
    verdict: AnswerVerdict.disputed,
    points: 0,
  ),
  AnswerLine(category: Category.movie, text: '', verdict: null, points: 0),
  AnswerLine(
    category: Category.food,
    text: 'Mango',
    verdict: AnswerVerdict.valid,
    points: 333,
  ),
  AnswerLine(
    category: Category.brand,
    text: 'Microsoft',
    verdict: AnswerVerdict.valid,
    points: 125,
  ),
];

Room _room(GamePhase phase) {
  final players = _eightPlayers();
  final ids = [for (final player in players) player.id];
  return Room(
    code: 'ABC234',
    phase: phase,
    players: players,
    usedLetters: const {'A', 'M', 'Q'},
    scores: {
      for (final id in ids)
        id: const ScoreLine(answerPoints: 12333, validationPoints: -12),
    },
    round: Round(
      number: 12,
      pickerId: localId,
      letter: phase == GamePhase.letterSelection ? null : 'M',
      deadline: clock.now().add(GameRules.answerTime),
      ballot: const [
        BallotItem(
          id: 'animal:madagascan hissing cockroach',
          category: Category.animal,
          text: 'Madagascan Hissing Cockroach',
        ),
      ],
      results: RoundResults(
        scores: {
          for (final id in ids)
            id: const ScoreLine(answerPoints: 2333, validationPoints: -3),
        },
        lines: {for (final id in ids) id: _longAnswers},
      ),
    ),
  );
}

/// Opens a screen that isn't part of a game.
Future<void> _openMenuScreen(WidgetTester tester, String route) async {
  await goToHome(tester);
  if (route != AppRoutes.home) await openRoute(tester, route);
}

void main() {
  for (final size in _phones) {
    for (final scale in _textScales) {
      final label = '${size.width.toInt()}px, text x$scale';

      for (final route in [
        AppRoutes.home,
        AppRoutes.wordBattle,
        AppRoutes.createRoom,
        AppRoutes.joinRoom,
        AppRoutes.settings,
        AppRoutes.howToPlay,
      ]) {
        testWidgets('$route fits at $label', (tester) async {
          await pumpGame(tester, size: size, textScale: scale);
          await _openMenuScreen(tester, route);
          await tester.pumpAndSettle();

          expect(currentRoute(tester), route);
        });
      }

      testWidgets('the splash screen fits at $label', (tester) async {
        await pumpGame(tester, size: size, textScale: scale);
        await goToHome(tester);
      });

      for (final phase in [
        GamePhase.lobby,
        GamePhase.letterSelection,
        GamePhase.validating,
        GamePhase.results,
      ]) {
        testWidgets('${phase.name} with 8 players fits at $label', (
          tester,
        ) async {
          await pumpGame(
            tester,
            size: size,
            textScale: scale,
            service: FakeGameService(_room(phase)),
          );
          await tester.pumpAndSettle();

          expect(currentRoute(tester), routeForPhase(phase));
        });
      }

      testWidgets('results with every card open fit at $label', (tester) async {
        await pumpGame(
          tester,
          size: size,
          textScale: scale,
          service: FakeGameService(_room(GamePhase.results)),
        );
        await tester.pumpAndSettle();

        final firstCard = find.text('Abdul Khader (you)');
        await tapAndSettle(tester, firstCard);
        expect(find.text('Madagascan Hissing Cockroach'), findsOneWidget);
      });

      testWidgets('the leaderboard keeps most of the screen at $label', (
        tester,
      ) async {
        await pumpGame(
          tester,
          size: size,
          textScale: scale,
          service: FakeGameService(_room(GamePhase.results)),
        );
        await tester.pumpAndSettle();

        final list = tester.getSize(find.byType(ListView)).height;
        expect(list, greaterThan(size.height * 0.6));
      });

      testWidgets('answering fits at $label', (tester) async {
        await pumpGame(
          tester,
          size: size,
          textScale: scale,
          service: FakeGameService(_room(GamePhase.answering)),
        );
        await pumpFrames(tester);

        expect(currentRoute(tester), AppRoutes.answering);
      });
    }
  }
}
