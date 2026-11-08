import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A chunky 3D title, like toy letters: each letter has its own candy
/// colour, a raised side in a darker shade, a navy outline, a glossy shine
/// across the top and a soft shadow below.
///
/// Only the front letters are a real `Text`, so screen readers and tests
/// read it once. Everything else is painted around it by two painters, and
/// the whole title is cached as one picture by a [RepaintBoundary], so the
/// extra layers cost nothing after the first frame.
class Title3D extends StatelessWidget {
  const Title3D(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.outlineWidth = 3,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double outlineWidth;

  /// How far the letters stand out, as a share of the font size.
  static const depthRatio = 0.11;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style
        .merge(style ?? AppText.title);
    final depth = scaler.scale(base.fontSize ?? 30) * depthRatio;

    // One colour per letter, skipping spaces.
    var next = 0;
    final colours = [
      for (final character in text.characters)
        character.trim().isEmpty
            ? null
            : AppColors.candy[next++ % AppColors.candy.length],
    ];
    final letters = text.characters.toList();

    TextSpan spans(Color? Function(Color colour) shade) => TextSpan(
      children: [
        for (final (index, character) in letters.indexed)
          TextSpan(
            text: character,
            style: colours[index] == null
                ? null
                : TextStyle(color: shade(colours[index]!)),
          ),
      ],
    );

    return RepaintBoundary(
      child: Padding(
        // Room for the raised side and shadow, which sit below the letters.
        padding: EdgeInsets.only(bottom: depth + outlineWidth),
        child: CustomPaint(
          painter: _DepthPainter(
            sides: spans((colour) => Color.lerp(colour, AppColors.navy, 0.4)),
            style: base,
            depth: depth,
            outlineWidth: outlineWidth,
            textAlign: textAlign,
            textScaler: scaler,
          ),
          foregroundPainter: _ShinePainter(
            text: text,
            style: base,
            textAlign: textAlign,
            textScaler: scaler,
          ),
          child: Text.rich(
            spans((colour) => colour),
            style: base,
            textAlign: textAlign,
            textScaler: scaler,
          ),
        ),
      ),
    );
  }
}

/// A [TextStyle] with only what affects the letters' shapes, so painted
/// copies line up exactly with the real text.
TextStyle _shapeOf(TextStyle style, {Color? color, Paint? foreground}) {
  return TextStyle(
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontVariations: style.fontVariations,
    height: style.height,
    letterSpacing: style.letterSpacing,
    color: color,
    foreground: foreground,
  );
}

/// Paints the soft shadow, the raised sides and the navy outline, behind
/// the real letters.
class _DepthPainter extends CustomPainter {
  _DepthPainter({
    required this.sides,
    required this.style,
    required this.depth,
    required this.outlineWidth,
    required this.textAlign,
    required this.textScaler,
  });

  final TextSpan sides;
  final TextStyle style;
  final double depth;
  final double outlineWidth;
  final TextAlign textAlign;
  final TextScaler textScaler;

  TextPainter _layout(TextSpan span, Size size) {
    return TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(minWidth: size.width, maxWidth: size.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plain = sides.toPlainText();
    Paint stroke(Color colour) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth * 2
      ..strokeJoin = StrokeJoin.round
      ..color = colour;

    final outline = _layout(
      TextSpan(
        text: plain,
        style: _shapeOf(style, foreground: stroke(AppColors.navy)),
      ),
      size,
    );
    final shadow = _layout(
      TextSpan(
        text: plain,
        style: _shapeOf(
          style,
          foreground: stroke(AppColors.navy.withValues(alpha: 0.3))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        ),
      ),
      size,
    );
    final side = _layout(
      TextSpan(style: _shapeOf(style), children: [sides]),
      size,
    );

    // A soft shadow on the ground, a little below the deepest layer.
    shadow.paint(canvas, Offset(0, depth + outlineWidth + 2));

    // The raised side: the outline, then the darker letters, stacked a
    // pixel at a time from the back, which reads as one solid block.
    final steps = depth.ceil();
    for (var step = steps; step >= 1; step--) {
      outline.paint(canvas, Offset(0, depth * step / steps));
    }
    for (var step = steps; step >= 1; step--) {
      side.paint(canvas, Offset(0, depth * step / steps));
    }

    // The outline around the front letters.
    outline.paint(canvas, Offset.zero);

    outline.dispose();
    shadow.dispose();
    side.dispose();
  }

  @override
  bool shouldRepaint(_DepthPainter old) {
    return old.sides != sides ||
        old.style != style ||
        old.depth != depth ||
        old.outlineWidth != outlineWidth ||
        old.textAlign != textAlign ||
        old.textScaler != textScaler;
  }
}

/// Paints a glossy white shine across the top of the front letters.
class _ShinePainter extends CustomPainter {
  _ShinePainter({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.15, 0.45, 0.55],
      ).createShader(Offset.zero & size);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _shapeOf(style, foreground: shine),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(minWidth: size.width, maxWidth: size.width);
    painter.paint(canvas, Offset.zero);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ShinePainter old) {
    return old.text != text ||
        old.style != style ||
        old.textAlign != textAlign ||
        old.textScaler != textScaler;
  }
}
