import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The soft game background used behind every screen.
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
          colors: [AppColors.background, AppColors.backgroundMint],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _bubble(top: -50, left: -40, size: 170, color: AppColors.sky),
          _bubble(top: 90, right: -56, size: 130, color: AppColors.sunshine),
          _bubble(
            bottom: -60,
            right: -30,
            size: 190,
            color: AppColors.lavender,
          ),
          _bubble(bottom: 110, left: -60, size: 120, color: AppColors.coral),
          child,
        ],
      ),
    );
  }

  Widget _bubble({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.22),
        ),
      ),
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
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxContentWidth,
              ),
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
                          _Header(title: title!, onBack: onBack),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
              ),
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
        Expanded(child: Text(title, style: AppText.title)),
      ],
    );
  }
}
