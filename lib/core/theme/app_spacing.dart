/// The spacing scale. Gaps and padding should use only these values.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner sizes for tiles, cards and pill-shaped buttons.
abstract final class AppRadius {
  static const double small = 16;
  static const double card = 24;
  static const double pill = 999;
}

/// Fixed sizes that keep the game comfortable for small hands.
abstract final class AppSizes {
  static const double minTapTarget = 56;
  static const double mainButton = 64;
  static const double maxContentWidth = 480;
}

/// Animation lengths, kept within the 150-400ms design range.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
