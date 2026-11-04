import 'dart:ui' show Color;

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import '../../models/room.dart';

/// "Round 2 of 5", for screens shown during a round.
String roundLabel(Room room) {
  return 'Round ${room.round?.number ?? 1} of ${room.settings.rounds}';
}

/// How each category looks. This lives with the UI so the [Category] model
/// stays free of Flutter.
extension CategoryStyle on Category {
  Color get color => switch (this) {
    Category.animal => AppColors.mint,
    Category.place => AppColors.sky,
    Category.person => AppColors.coral,
    Category.movie => AppColors.lavender,
    Category.food => AppColors.sunshine,
    Category.brand => AppColors.peach,
  };

  /// The illustrated picture, from `tool/import_category_pictures.py`.
  String get picture => 'assets/images/categories/$name.webp';

  String get character => switch (this) {
    Category.animal => AppAssets.fox,
    Category.place => AppAssets.penguin,
    Category.person => AppAssets.owl,
    Category.movie => AppAssets.cat,
    Category.food => AppAssets.bear,
    Category.brand => AppAssets.parrot,
  };
}
