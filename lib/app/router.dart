import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../features/home/home_screen.dart';
import '../features/home/splash_screen.dart';
import '../features/lobby/create_room_screen.dart';
import '../features/lobby/join_room_screen.dart';

/// The address of every screen.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const createRoom = '/create';
  static const joinRoom = '/join';
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

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _gamePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _gamePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.createRoom,
        pageBuilder: (context, state) =>
            _gamePage(state, const CreateRoomScreen()),
      ),
      GoRoute(
        path: AppRoutes.joinRoom,
        pageBuilder: (context, state) =>
            _gamePage(state, const JoinRoomScreen()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
