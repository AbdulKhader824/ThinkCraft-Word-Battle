import 'package:flutter/material.dart';

/// Every colour in the game. Screens use these names, never raw hex codes.
abstract final class AppColors {
  static const navy = Color(0xFF1B2A5B);
  static const navySoft = Color(0xFF4A5680);
  static const mint = Color(0xFF3DDC97);
  static const mintDeep = Color(0xFF22A871);
  static const sky = Color(0xFF4FB8F0);
  static const skyDeep = Color(0xFF2B8FC7);
  static const sunshine = Color(0xFFFFD23F);
  static const sunshineDeep = Color(0xFFD9A900);
  static const coral = Color(0xFFFF8A80);
  static const coralDeep = Color(0xFFD9635A);
  static const lavender = Color(0xFFB79CED);
  static const lavenderDeep = Color(0xFF8E70CC);
  static const peach = Color(0xFFFFB26B);

  static const valid = Color(0xFF15803D);
  static const validDeep = Color(0xFF0F5F2D);
  static const invalid = Color(0xFFC62828);
  static const invalidDeep = Color(0xFF8E1C1C);

  static const gold = Color(0xFFD9A900);
  static const silver = Color(0xFF8A94A6);
  static const bronze = Color(0xFFB5763A);

  /// Soft circles behind each player's character.
  static const avatarTints = [
    Color(0xFFE3F4FF),
    Color(0xFFFFF4CC),
    Color(0xFFEDE6FB),
    Color(0xFFFFE6E3),
    Color(0xFFE3F9EF),
    Color(0xFFFFEEDD),
    Color(0xFFDFF3FF),
    Color(0xFFF3ECFF),
  ];

  /// The sky behind every screen, from top to bottom.
  static const skyTop = Color(0xFFA9DCFF);
  static const skyBottom = Color(0xFFE3F4FF);

  /// Warm paper colour for cards.
  static const cream = Color(0xFFFFF8EC);
  static const creamFold = Color(0xFFF0DDBF);

  /// Bright candy colours for tiles and rainbow titles. Numbers on them are
  /// white with a navy outline, which reads on every one of these.
  static const candy = [
    Color(0xFFFF6B8B),
    Color(0xFFFF9F43),
    Color(0xFF3CCB6E),
    Color(0xFF22B5A8),
    Color(0xFF4D7CFE),
    Color(0xFFF2B705),
    Color(0xFFFF7A3D),
    Color(0xFFA56BFA),
  ];

  static const background = Color(0xFFF4FBFF);
  static const backgroundMint = Color(0xFFE3F9EF);
  static const surface = Colors.white;
  static const outline = Color(0xFFD5DEEC);
  static const disabled = Color(0xFFDDE3EC);
  // Darkened from 0xFF5C6680, which only reached 4.44:1 on [disabled].
  static const disabledText = Color(0xFF4F5973);
}
