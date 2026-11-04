import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Text with a solid outline, drawn in two passes: an outline behind, then
/// the coloured text on top.
///
/// The outline is painted, not a second `Text`, so screen readers and tests
/// still find exactly one piece of text. This is far cheaper than building
/// an outline from eight shadows, which drew every letter nine times.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.outlineWidth = 2,
    this.outlineColor = AppColors.navy,
    this.dropShadow = false,
    this.textScaler,
  }) : span = null;

  /// Text made of [span]s, such as a different colour for each letter.
  const OutlinedText.rich(
    TextSpan this.span, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.outlineWidth = 2,
    this.outlineColor = AppColors.navy,
    this.dropShadow = false,
    this.textScaler,
  }) : text = null;

  final String? text;
  final TextSpan? span;
  final TextStyle? style;
  final TextAlign textAlign;
  final double outlineWidth;
  final Color outlineColor;

  /// Adds a solid shadow below, which makes letters look raised.
  final bool dropShadow;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final scaler = textScaler ?? MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    final fill = dropShadow
        ? base.copyWith(
            shadows: [
              Shadow(color: outlineColor, offset: Offset(0, outlineWidth + 2)),
            ],
          )
        : base;
    final plain = text ?? span!.toPlainText();

    final shown = span == null
        ? Text(text!, style: fill, textAlign: textAlign, textScaler: scaler)
        : Text.rich(
            span!,
            style: fill,
            textAlign: textAlign,
            textScaler: scaler,
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _OutlinePainter(
                text: plain,
                style: base,
                width: outlineWidth,
                color: outlineColor,
                textAlign: textAlign,
                textScaler: scaler,
              ),
            ),
          ),
        ),
        shown,
      ],
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.text,
    required this.style,
    required this.width,
    required this.color,
    required this.textAlign,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final double width;
  final Color color;
  final TextAlign textAlign;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    // A stroke is centred on each letter's edge, so it is twice as wide as
    // the outline that shows outside the letter.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 2
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontVariations: style.fontVariations,
          height: style.height,
          letterSpacing: style.letterSpacing,
          foreground: stroke,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(minWidth: size.width, maxWidth: size.width);

    painter.paint(canvas, Offset.zero);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_OutlinePainter old) {
    return old.text != text ||
        old.style != style ||
        old.width != width ||
        old.color != color ||
        old.textAlign != textAlign ||
        old.textScaler != textScaler;
  }
}
