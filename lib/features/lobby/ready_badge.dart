import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';

/// Shows whether a player is ready. It gently pulses while waiting, and
/// pops in a tick once they are ready.
class ReadyBadge extends StatefulWidget {
  const ReadyBadge({super.key, required this.isReady});

  final bool isReady;

  @override
  State<ReadyBadge> createState() => _ReadyBadgeState();
}

class _ReadyBadgeState extends State<ReadyBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: 0.4,
    value: 1,
  );

  bool get _shouldPulse {
    return !widget.isReady && !MediaQuery.disableAnimationsOf(context);
  }

  void _updatePulse() {
    if (_shouldPulse) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulse();
  }

  @override
  void didUpdateWidget(ReadyBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : AppDurations.medium,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
      child: widget.isReady
          ? _content(key: const ValueKey('ready'), ready: true)
          : FadeTransition(
              key: const ValueKey('waiting'),
              opacity: _pulse,
              child: _content(ready: false),
            ),
    );
  }

  Widget _content({Key? key, required bool ready}) {
    // Shrinks to fit the narrow player cards on small phones.
    return FittedBox(
      key: key,
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            color: AppColors.navy,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(ready ? 'Ready' : 'Waiting', style: AppText.bodySmall),
        ],
      ),
    );
  }
}
