import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'rainbow_title.dart';
import 'entrance.dart';

/// The sky behind every screen: soft clouds, a smiling sun and a few
/// stars. It never takes taps, and sits behind everything.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The scenery never changes, so it's drawn once and reused.
          RepaintBoundary(
            child: IgnorePointer(
              child: Stack(
                children: [
                  _sticker(AppAssets.sun, top: -34, right: -34, width: 130),
                  _sticker(AppAssets.cloud, top: 70, left: -40, width: 150),
                  _sticker(AppAssets.cloud, top: 230, right: -50, width: 120),
                  _sticker(AppAssets.cloud, bottom: 40, left: -30, width: 170),
                  _sticker(AppAssets.star, top: 14, left: 18, width: 26),
                  _sticker(AppAssets.star, bottom: 150, right: 14, width: 30),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _sticker(
    String asset, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double width,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SvgPicture.asset(asset, width: width),
    );
  }
}

/// The shared page frame: background, safe area, scrolling and a width limit
/// so the layout stays phone-shaped on bigger screens.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.child, this.title, this.onBack});

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.md * 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (title != null) ...[
                  Entrance(
                    child: _Header(title: title!, onBack: onBack),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Entrance(index: 1, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The base of every screen: background, safe area, and a width limit so
/// layouts stay phone-shaped on tablets and wide browser windows.
///
/// Screens with their own layout, such as a fixed header above a scrolling
/// list, use this directly instead of [GameScreen].
class GameFrame extends StatelessWidget {
  const GameFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxContentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: IconButton(
              tooltip: 'Back',
              iconSize: 28,
              constraints: const BoxConstraints(
                minWidth: AppSizes.minTapTarget,
                minHeight: AppSizes.minTapTarget,
              ),
              color: AppColors.navy,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Long titles shrink to fit rather than wrap or overflow.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RainbowTitle(title),
          ),
        ),
      ],
    );
  }
}
