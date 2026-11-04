import 'dart:async';

import 'package:flutter/material.dart';

/// Slides and fades its child in once, a little after the items before it.
///
/// Give each item in a list its [index] to make them arrive one by one. It
/// plays once and then costs nothing, and shows instantly when the phone
/// asks for reduced motion.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 60),
    this.rise = 24,
    this.fromScale = 1,
  });

  final Widget child;
  final int index;

  /// The gap between one item and the next.
  final Duration step;

  /// How far, in pixels, the child rises as it arrives.
  final double rise;

  /// Below 1, the child also grows into place, like a pop.
  final double fromScale;

  static const duration = Duration(milliseconds: 380);

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Entrance.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: widget.fromScale < 1 ? Curves.easeOutBack : Curves.easeOutCubic,
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (widget.index == 0) {
      _controller.forward();
    } else {
      _delay = Timer(widget.step * widget.index, _controller.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final value = _curve.value;
        return Opacity(
          opacity: _controller.value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.rise),
            child: widget.fromScale < 1
                ? Transform.scale(
                    scale: widget.fromScale + (1 - widget.fromScale) * value,
                    child: child,
                  )
                : child,
          ),
        );
      },
    );
  }
}
