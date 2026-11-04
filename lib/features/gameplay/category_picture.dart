import 'package:flutter/material.dart';

import '../../models/category.dart';
import 'category_style.dart';

/// A category's illustrated picture, framed in its own colour.
///
/// Pictures are 3:2. Give a [height]; the width follows.
class CategoryPicture extends StatelessWidget {
  const CategoryPicture({
    super.key,
    required this.category,
    required this.height,
    this.semanticLabel,
  });

  static const aspectRatio = 3 / 2;

  final Category category;
  final double height;

  /// Read aloud when set. Leave null where the label is already shown.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Every size shares one decoded copy, which the splash screen loads
    // ahead of time, so pictures appear at once instead of popping in.
    return Image.asset(
      category.picture,
      height: height,
      width: height * aspectRatio,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      filterQuality: FilterQuality.medium,
    );
  }
}
