import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'outlined_text.dart';

/// A glossy, candy-coloured tile for numbers and letters.
///
/// The chosen tile wears a crown and a white ring. A used tile turns grey.
/// [onTap] is null when the tile can't be chosen.
class CandyTile extends StatelessWidget {
  const CandyTile({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    required this.semanticsLabel,
    this.tapKey,
    this.selected = false,
    this.used = false,
    this.width = AppSizes.minTapTarget,
    this.height = AppSizes.minTapTarget,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String semanticsLabel;

  /// Put on the tappable part, so tests can find and tap it.
  final Key? tapKey;
  final bool selected;
  final bool used;
  final double width;
  final double height;

  static const _edge = 5.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final face = used ? AppColors.disabled : color;
    final edge = used
        ? AppColors.outline
        : Color.lerp(color, AppColors.navy, 0.35)!;
    final radius = BorderRadius.circular(AppRadius.small);

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: selected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: [
                  BoxShadow(color: edge, offset: const Offset(0, _edge)),
                  if (selected)
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(face, Colors.white, 0.3)!, face],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: tapKey,
                  borderRadius: radius,
                  onTap: onTap,
                  child: Stack(
                    children: [
                      // A soft shine in the top corner, like a sweet.
                      Positioned(
                        top: height * 0.1,
                        left: width * 0.14,
                        child: Container(
                          width: width * 0.28,
                          height: height * 0.14,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: used ? 0.25 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Label(label: label, used: used),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -height * 0.42,
                left: width * 0.2,
                right: width * 0.2,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: AppDurations.slow,
                    curve: Curves.elasticOut,
                    builder: (context, value, crown) => Transform.translate(
                      offset: Offset(0, (1 - value) * -height * 0.3),
                      child: Transform.scale(scale: value, child: crown),
                    ),
                    child: SvgPicture.asset(
                      AppAssets.crown,
                      height: height * 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.used});

  final String label;
  final bool used;

  @override
  Widget build(BuildContext context) {
    if (used) {
      return Text(
        label,
        textScaler: TextScaler.noScaling,
        style: AppText.heading.copyWith(color: AppColors.disabledText),
      );
    }
    // White with a navy outline reads on every candy colour.
    return OutlinedText(
      label,
      textScaler: TextScaler.noScaling,
      style: AppText.heading.copyWith(color: Colors.white),
    );
  }
}
