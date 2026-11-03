import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The colour pairs a [GameButton] can use.
enum GameButtonStyle {
  mint(AppColors.mint, AppColors.mintDeep),
  sunshine(AppColors.sunshine, AppColors.sunshineDeep),
  sky(AppColors.sky, AppColors.skyDeep),
  coral(AppColors.coral, AppColors.coralDeep),
  lavender(AppColors.lavender, AppColors.lavenderDeep);

  const GameButtonStyle(this.face, this.edge);

  final Color face;
  final Color edge;
}

/// A chunky game button that sinks into its coloured edge when pressed.
///
/// Passing a null [onPressed] shows the disabled style.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = GameButtonStyle.mint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonStyle style;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  static const _edgeDepth = 6.0;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final face = enabled ? widget.style.face : AppColors.disabled;
    final edge = enabled ? widget.style.edge : AppColors.outline;
    final textColor = enabled ? AppColors.navy : AppColors.disabledText;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sink = _pressed ? _edgeDepth - 2 : 0.0;
    final radius = BorderRadius.circular(AppRadius.pill);

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppDurations.fast,
      curve: Curves.easeOut,
      margin: EdgeInsets.only(top: sink, bottom: _edgeDepth - sink),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: edge, offset: Offset(0, _edgeDepth - sink)),
        ],
      ),
      child: Material(
        color: face,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onPressed,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.mainButton,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: textColor, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: AppText.button.copyWith(color: textColor),
                    ),
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
