import 'package:flutter/material.dart';

import 'title_3d.dart';

/// A playful title where each letter has its own candy colour, a navy
/// outline and a raised 3D side, like chunky toy letters. Every screen
/// header uses it.
///
/// It is one piece of text, so screen readers and tests read it normally.
class RainbowTitle extends StatelessWidget {
  const RainbowTitle(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.outlineWidth = 2.5,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double outlineWidth;

  @override
  Widget build(BuildContext context) {
    return Title3D(
      text,
      style: style,
      textAlign: textAlign,
      outlineWidth: outlineWidth,
    );
  }
}
