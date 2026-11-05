import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/rainbow_title.dart';
import '../../models/category.dart';
import '../../services/sound_service.dart';
import '../gameplay/category_style.dart';
import '../hub/game_catalog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const displayTime = Duration(milliseconds: 1800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.displayTime, () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    _warmUp();
  }

  /// Loads the pictures used later while the splash is showing, so screens
  /// don't stutter or pop in the first time they open.
  void _warmUp() {
    // Creating the sound player loads every sound, so even the first swipe
    // or tap is heard.
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(soundPlayerProvider);
    } on StateError {
      // Shown outside the app, as in some widget tests: nothing to load.
    }
    for (final category in Category.values) {
      precacheImage(AssetImage(category.picture), context, onError: (_, _) {});
    }
    // The first few game cards are on screen as soon as the hub opens.
    for (final game in GameCatalog.games.take(3)) {
      precacheImage(AssetImage(game.picture), context, onError: (_, _) {});
    }
    for (final path in [
      ...AppAssets.stickers,
      ...AppAssets.animals,
      AppAssets.tilo,
    ]) {
      final loader = SvgAssetLoader(path);
      svg.cache
          .putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null))
          .ignore();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GameFrame(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : 0.7, end: 1),
            duration: AppDurations.slow,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            // Shrinks on small phones with large text, since nothing scrolls.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    AppAssets.logo,
                    width: 200,
                    semanticsLabel: '${AppStrings.appName} logo',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  RainbowTitle(
                    AppStrings.appName,
                    style: AppText.display,
                    textAlign: TextAlign.center,
                    outlineWidth: 3,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.tagline,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
