import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/room.dart';
import '../services/game_providers.dart';
import 'router.dart';

class ThinkCraftApp extends ConsumerWidget {
  const ThinkCraftApp({super.key});

  /// Large system text is supported up to this size. Beyond it, letter
  /// tiles and game cards would no longer fit on a phone.
  static const maxTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a nearby room the screen stays on: if the host's phone slept,
    // Android could pause the game for everyone.
    ref.listen(gameRoomProvider, (previous, next) {
      final wasNearby = previous?.mode == RoomMode.nearby;
      final isNearby = next?.mode == RoomMode.nearby;
      if (wasNearby != isNearby) _keepScreenOn(isNearby);
    });

    return MaterialApp.router(
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

void _keepScreenOn(bool on) {
  // Tests and the web may not have the plugin; the game works without it.
  WakelockPlus.toggle(enable: on).catchError((Object _) {});
}
