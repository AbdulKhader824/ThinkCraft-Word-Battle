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
  static const invalid = Color(0xFFC62828);

  static const background = Color(0xFFF4FBFF);
  static const backgroundMint = Color(0xFFE3F9EF);
  static const surface = Colors.white;
  static const outline = Color(0xFFD5DEEC);
  static const disabled = Color(0xFFDDE3EC);
  static const disabledText = Color(0xFF5C6680);
}
