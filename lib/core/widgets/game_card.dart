import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A rounded card that groups content on a screen. By default it looks like
/// warm paper, optionally with a folded corner and a sticker on top.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.color = AppColors.cream,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.foldedCorner = false,
    this.sticker,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// Folds the bottom-right corner, like a page.
  final bool foldedCorner;

  /// A small decoration that peeks over the top-right corner.
  final Widget? sticker;

  static const _fold = 26.0;

  @override
  Widget build(BuildContext context) {
    final radius = foldedCorner
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.card),
            topRight: Radius.circular(AppRadius.card),
            bottomLeft: Radius.circular(AppRadius.card),
            bottomRight: Radius.circular(AppRadius.small / 2),
          )
        : BorderRadius.circular(AppRadius.card);

    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.navy.withValues(alpha: 0.08),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (!foldedCorner && sticker == null) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (foldedCorner)
          const Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.square(_fold),
                painter: _FoldPainter(),
              ),
            ),
          ),
        if (sticker != null)
          Positioned(
            top: -AppSpacing.lg,
            right: -AppSpacing.xs,
            child: IgnorePointer(child: sticker!),
          ),
      ],
    );
  }
}

/// Draws the turned-up corner of a page.
class _FoldPainter extends CustomPainter {
  const _FoldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fold = Path()
      ..moveTo(size.width, 0)
      ..quadraticBezierTo(size.width * 0.15, size.height * 0.15, 0, size.height)
      ..lineTo(size.width * 0.55, size.height * 0.55)
      ..close();
    canvas.drawShadow(fold, AppColors.navy, 3, false);
    canvas.drawPath(fold, Paint()..color = AppColors.creamFold);
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) => false;
}
