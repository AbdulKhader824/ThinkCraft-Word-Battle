import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/game_phase.dart';

void main() {
  test('every phase has its own screen', () {
    final routes = GamePhase.values.map(routeForPhase).toSet();

    expect(routes, hasLength(GamePhase.values.length));
    expect(routes, AppRoutes.gameRoutes);
  });

  group('gameRedirect', () {
    test('leaves normal screens alone when there is no game', () {
      expect(gameRedirect(AppRoutes.home, null), isNull);
      expect(gameRedirect(AppRoutes.createRoom, null), isNull);
    });

    test('sends game screens home when there is no game', () {
      for (final route in AppRoutes.gameRoutes) {
        expect(gameRedirect(route, null), AppRoutes.home);
      }
    });

    test('stays put on the right screen for the phase', () {
      for (final phase in GamePhase.values) {
        expect(gameRedirect(routeForPhase(phase), phase), isNull);
      }
    });

    test('moves every other screen to the current phase', () {
      expect(
        gameRedirect(AppRoutes.createRoom, GamePhase.lobby),
        AppRoutes.lobby,
      );
      expect(
        gameRedirect(AppRoutes.lobby, GamePhase.letterSelection),
        AppRoutes.letterSelection,
      );
      expect(
        gameRedirect(AppRoutes.home, GamePhase.answering),
        AppRoutes.answering,
      );
    });
  });
}
