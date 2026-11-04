import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A single shower of confetti that falls once and fades away.
///
/// It plays nothing when the phone asks for reduced motion, and ignores
/// taps so it never blocks the buttons underneath.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70});

  static const duration = Duration(milliseconds: 2800);

  final int pieces;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    AppColors.mint,
    AppColors.sky,
    AppColors.sunshine,
    AppColors.coral,
    AppColors.lavender,
    AppColors.peach,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ConfettiBurst.duration,
  );
  late final List<_Piece> _pieces;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _pieces = List.generate(
      widget.pieces,
      (_) => _Piece.random(random, _colors),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reduceMotion && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return const SizedBox.shrink();

    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.isRound,
  });

  factory _Piece.random(Random random, List<Color> colors) {
    double between(double low, double high) {
      return low + random.nextDouble() * (high - low);
    }

    return _Piece(
      x: random.nextDouble(),
      delay: between(0, 0.3),
      speed: between(0.8, 1.3),
      drift: between(-0.08, 0.08),
      spin: between(-8, 8),
      size: between(7, 12),
      color: colors[random.nextInt(colors.length)],
      isRound: random.nextBool(),
    );
  }

  /// Across the screen, from 0 to 1.
  final double x;

  /// How late this piece starts, as part of the whole animation.
  final double delay;
  final double speed;
  final double drift;
  final double spin;
  final double size;
  final Color color;
  final bool isRound;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress) : super(repaint: progress);

  final List<_Piece> pieces;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final piece in pieces) {
      final t = ((progress.value - piece.delay) / (1 - piece.delay)).clamp(
        0.0,
        1.0,
      );
      if (t == 0 || t == 1) continue;

      final opacity = t > 0.75 ? (1 - t) / 0.25 : 1.0;
      final dx = (piece.x + piece.drift * sin(t * pi * 3)) * size.width;
      final dy = (-0.05 + t * t * piece.speed * 1.1) * size.height;

      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(t * piece.spin);
      paint.color = piece.color.withValues(alpha: opacity);
      if (piece.isRound) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
