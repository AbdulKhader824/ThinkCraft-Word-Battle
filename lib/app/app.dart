import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/room.dart';
import '../services/drawing/drawing_providers.dart';
import '../services/game_providers.dart';
import '../services/impostor/impostor_providers.dart';
import 'router.dart';

class ThinkCraftApp extends ConsumerWidget {
  const ThinkCraftApp({super.key});

  /// Large system text is supported up to this size. Beyond it, letter
  /// tiles and game cards would no longer fit on a phone.
  static const maxTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a room with friends, nearby or online, the screen stays on: if the
    // host's phone slept, Android could pause the game for everyone.
    ref.listen(gameRoomProvider, (previous, next) {
      bool withFriends(Room? room) =>
          room != null && room.mode != RoomMode.practice;
      final wasOn = withFriends(previous);
      final isOn = withFriends(next);
      if (wasOn != isOn) _keepScreenOn(isOn);
    });
    // Guess the Drawing rooms are always with friends.
    ref.listen(drawingRoomProvider, (previous, next) {
      if ((previous == null) != (next == null)) _keepScreenOn(next != null);
    });
    // So are Impostor rooms.
    ref.listen(impostorRoomProvider, (previous, next) {
      if ((previous == null) != (next == null)) _keepScreenOn(next != null);
    });
    // A snack bar sits above every screen, so it stays while the app goes
    // home from a room that closed.
    ref.listen(roomNoticeProvider, (_, notice) {
      if (notice == null) return;
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice.message)));
    });

    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: AppStrings.appName,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: child!,
      ),
    );
  }
}

final _messenger = GlobalKey<ScaffoldMessengerState>();

void _keepScreenOn(bool on) {
  // Tests and the web may not have the plugin; the game works without it.
  WakelockPlus.toggle(enable: on).catchError((Object _) {});
}
