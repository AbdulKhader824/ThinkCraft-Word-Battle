import 'dart:ui' show Color;

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
  /// The six candy colours take turns, so neighbours never match.
  Color get color => switch (this) {
    Category.animal || Category.cartoon || Category.vehicle => AppColors.mint,
    Category.bird || Category.food || Category.sport => AppColors.sky,
    Category.place || Category.vegetable || Category.game => AppColors.coral,
    Category.person || Category.flower => AppColors.lavender,
    Category.celebrity || Category.thing => AppColors.sunshine,
    Category.movie || Category.brand => AppColors.peach,
  };

  /// The illustrated picture, from `tool/import_category_pictures.py`.
  String get picture => 'assets/images/categories/$name.webp';
}
