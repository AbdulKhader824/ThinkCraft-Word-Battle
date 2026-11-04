import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';

/// Tilo, the game's mascot, with a gentle floating animation.
///
/// The animation stops when the phone asks for reduced motion.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.size = 160});

  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  static const _floatDistance = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _float = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Floating redraws only Tilo, not the screen around it.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          final offset = (_float.value - 0.5) * _floatDistance * 2;
          return Transform.translate(offset: Offset(0, offset), child: child);
        },
        child: SvgPicture.asset(
          AppAssets.tilo,
          width: widget.size,
          height: widget.size,
          semanticsLabel: 'Tilo, the game mascot',
        ),
      ),
    );
  }
}
