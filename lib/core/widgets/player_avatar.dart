import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// A player's animal character inside a coloured circle.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.index, this.size = 56});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final position = index % AppAssets.animals.length;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.avatarTints[position],
        border: Border.all(color: AppColors.surface, width: 3),
      ),
      child: SvgPicture.asset(
        AppAssets.animals[position],
        semanticsLabel: AppAssets.animalNames[position],
      ),
    );
  }
}
