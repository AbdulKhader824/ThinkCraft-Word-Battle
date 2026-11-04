import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A ring that drains as time runs out.
///
/// It works out the time left from [deadline] on every update, rather than
/// counting down, so it is still right after the app has been in the
/// background.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.deadline,
    required this.total,
    this.size = 76,
    this.onSecond,
  });

  final DateTime deadline;
  final Duration total;
  final double size;

  /// Called each time the whole seconds left goes down, such as from 6
  /// to 5.
  final ValueChanged<int>? onSecond;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> {
  static const _updateEvery = Duration(milliseconds: 200);

  // Colours change at the same share of any timer: for 90 seconds that's
  // yellow at 30 and red at 10, and for 30 seconds it's 10 and 4.
  int get _warningSeconds => (widget.total.inSeconds / 3).ceil();
  int get _dangerSeconds => (widget.total.inSeconds / 9).ceil();

  late final Timer _timer;
  late int _lastSecond;

  int get _secondsLeft {
    final left = widget.deadline.difference(clock.now());
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _lastSecond = _secondsLeft;
    _timer = Timer.periodic(_updateEvery, (_) {
      final seconds = _secondsLeft;
      if (seconds < _lastSecond) widget.onSecond?.call(seconds);
      _lastSecond = seconds;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _colorFor(int seconds) {
    if (seconds <= _dangerSeconds) return AppColors.coralDeep;
    if (seconds <= _warningSeconds) return AppColors.sunshineDeep;
    return AppColors.mintDeep;
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(clock.now());
    final clamped = left.isNegative ? Duration.zero : left;
    final seconds = (clamped.inMilliseconds / 1000).ceil();
    final progress = clamped.inMilliseconds / widget.total.inMilliseconds;

    return Semantics(
      label: '$seconds seconds left',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress.clamp(0, 1),
            color: _colorFor(seconds),
          ),
          child: Center(child: Text('$seconds', style: AppText.heading)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  static const _strokeWidth = 9.0;

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, Paint()..color = AppColors.surface);
    canvas.drawCircle(center, radius, paint..color = AppColors.outline);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
