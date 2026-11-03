import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../features/gameplay/answer_screen.dart';
import '../features/gameplay/letter_selection_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/splash_screen.dart';
import '../features/lobby/create_room_screen.dart';
import '../features/lobby/join_room_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/results/results_screen.dart';
import '../features/validation/validation_screen.dart';
import '../models/game_phase.dart';
import '../services/game_providers.dart';

/// The address of every screen.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const createRoom = '/create';
  static const joinRoom = '/join';
  static const lobby = '/lobby';
  static const letterSelection = '/letter';
  static const answering = '/answers';
  static const validation = '/validation';
  static const results = '/results';

  static const gameRoutes = {
    lobby,
    letterSelection,
    answering,
    validation,
    results,
  };
}

/// The screen for each stage of the game.
String routeForPhase(GamePhase phase) {
  return switch (phase) {
    GamePhase.lobby => AppRoutes.lobby,
    GamePhase.letterSelection => AppRoutes.letterSelection,
    GamePhase.answering => AppRoutes.answering,
    GamePhase.validating => AppRoutes.validation,
    GamePhase.results => AppRoutes.results,
  };
}

/// Decides where the app should be. During a game, the game's phase chooses
/// the screen. With no game, game screens send the player home.
String? gameRedirect(String location, GamePhase? phase) {
  if (phase == null) {
    return AppRoutes.gameRoutes.contains(location) ? AppRoutes.home : null;
  }
  final target = routeForPhase(phase);
  return location == target ? null : target;
}

/// Goes back a screen, or home if there is nothing to go back to. That can
/// happen on the web, where a screen can be opened directly from its address.
void goBackOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

Page<void> _gamePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.medium,
    reverseTransitionDuration: AppDurations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

GoRoute _route(String path, Widget screen) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => _gamePage(state, screen),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final phase = ValueNotifier<GamePhase?>(ref.read(gameRoomProvider)?.phase);
  ref.listen(gameRoomProvider, (_, room) => phase.value = room?.phase);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: phase,
    redirect: (context, state) =>
        gameRedirect(state.matchedLocation, phase.value),
    routes: [
      _route(AppRoutes.splash, const SplashScreen()),
      _route(AppRoutes.home, const HomeScreen()),
      _route(AppRoutes.createRoom, const CreateRoomScreen()),
      _route(AppRoutes.joinRoom, const JoinRoomScreen()),
      _route(AppRoutes.lobby, const LobbyScreen()),
      _route(AppRoutes.letterSelection, const LetterSelectionScreen()),
      _route(AppRoutes.answering, const AnswerScreen()),
      _route(AppRoutes.validation, const ValidationScreen()),
      _route(AppRoutes.results, const ResultsScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    phase.dispose();
  });
  return router;
});
