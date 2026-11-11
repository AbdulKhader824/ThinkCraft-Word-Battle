import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/drawing/drawing_create_screen.dart';
import '../features/drawing/drawing_home_screen.dart';
import '../features/drawing/drawing_how_to_play_screen.dart';
import '../features/drawing/drawing_lobby_screen.dart';
import '../features/drawing/drawing_play_screen.dart';
import '../features/drawing/drawing_results_screen.dart';
import '../features/gameplay/answer_screen.dart';
import '../features/gameplay/letter_selection_screen.dart';
import '../features/home/word_battle_screen.dart';
import '../features/home/splash_screen.dart';
import '../features/hub/game_catalog.dart';
import '../features/hub/hub_screen.dart';
import '../features/lobby/create_room_screen.dart';
import '../features/lobby/join_room_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/results/results_screen.dart';
import '../features/settings/how_to_play_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/validation/validation_screen.dart';
import '../models/drawing_room.dart';
import '../models/game_phase.dart';
import '../services/drawing/drawing_providers.dart';
import '../services/game_providers.dart';
import '../services/nearby/nearby_discovery.dart';

/// The address of every screen.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const wordBattle = GameCatalog.wordBattleRoute;
  static const createRoom = '/create';
  static const joinRoom = '/join';
  static const settings = '/settings';
  static const howToPlay = '/how-to-play';
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

  // Guess the Drawing.
  static const drawing = GameCatalog.guessTheDrawingRoute;
  static const drawingCreate = '$drawing/create';
  static const drawingJoin = '$drawing/join';
  static const drawingHowToPlay = '$drawing/how-to-play';
  static const drawingLobby = '$drawing/lobby';
  static const drawingPlay = '$drawing/play';
  static const drawingResults = '$drawing/results';

  static const drawingGameRoutes = {drawingLobby, drawingPlay, drawingResults};
}

/// The Guess the Drawing screen for each stage of its game. Picking a word,
/// drawing and the turn's result share one screen, so the drawing stays
/// put between them.
String routeForDrawingPhase(DrawingPhase phase) {
  return switch (phase) {
    DrawingPhase.lobby => AppRoutes.drawingLobby,
    DrawingPhase.choosing ||
    DrawingPhase.drawing ||
    DrawingPhase.turnResult => AppRoutes.drawingPlay,
    DrawingPhase.results => AppRoutes.drawingResults,
  };
}

/// Like [gameRedirect], for Guess the Drawing. Returns null when the
/// drawing game has nothing to say about [location].
String? drawingRedirect(String location, DrawingPhase? phase) {
  if (phase == null) {
    return AppRoutes.drawingGameRoutes.contains(location)
        ? AppRoutes.home
        : null;
  }
  final target = routeForDrawingPhase(phase);
  return location == target ? null : target;
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

const _pageTransition = Duration(milliseconds: 300);

Page<void> _gamePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _pageTransition,
    reverseTransitionDuration: _pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;

      // The new screen fades in while growing gently into place.
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
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
  final drawingPhase = ValueNotifier<DrawingPhase?>(
    ref.read(drawingRoomProvider)?.phase,
  );
  ref.listen(
    drawingRoomProvider,
    (_, room) => drawingPhase.value = room?.phase,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([phase, drawingPhase]),
    redirect: (context, state) {
      final location = state.matchedLocation;
      // A drawing game in progress decides where to be; otherwise Word
      // Battle does, and sends drawing game screens home.
      if (drawingPhase.value != null) {
        return drawingRedirect(location, drawingPhase.value);
      }
      return drawingRedirect(location, null) ??
          gameRedirect(location, phase.value);
    },
    routes: [
      _route(AppRoutes.splash, const SplashScreen()),
      _route(AppRoutes.home, const HubScreen()),
      _route(AppRoutes.wordBattle, const WordBattleScreen()),
      _route(AppRoutes.createRoom, const CreateRoomScreen()),
      _route(AppRoutes.joinRoom, const JoinRoomScreen()),
      _route(AppRoutes.settings, const SettingsScreen()),
      _route(AppRoutes.howToPlay, const HowToPlayScreen()),
      _route(AppRoutes.lobby, const LobbyScreen()),
      _route(AppRoutes.letterSelection, const LetterSelectionScreen()),
      _route(AppRoutes.answering, const AnswerScreen()),
      _route(AppRoutes.validation, const ValidationScreen()),
      _route(AppRoutes.results, const ResultsScreen()),
      _route(AppRoutes.drawing, const DrawingHomeScreen()),
      _route(AppRoutes.drawingCreate, const DrawingCreateScreen()),
      _route(
        AppRoutes.drawingJoin,
        const JoinRoomScreen(game: NearbyRoomInfo.guessTheDrawing),
      ),
      _route(AppRoutes.drawingHowToPlay, const DrawingHowToPlayScreen()),
      _route(AppRoutes.drawingLobby, const DrawingLobbyScreen()),
      _route(AppRoutes.drawingPlay, const DrawingPlayScreen()),
      _route(AppRoutes.drawingResults, const DrawingResultsScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    phase.dispose();
    drawingPhase.dispose();
  });
  return router;
});
