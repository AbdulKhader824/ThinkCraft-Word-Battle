import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/constants/app_constants.dart';
import 'package:thinkcraft_word_battle/features/gameplay/category_style.dart';
import 'package:thinkcraft_word_battle/models/category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in const [
    AppAssets.logo,
    AppAssets.tilo,
    ...AppAssets.animals,
    ...AppAssets.stickers,
  ]) {
    test('$path is bundled and parses as SVG', () async {
      final svg = await rootBundle.loadString(path);
      final picture = await vg.loadPicture(SvgStringLoader(svg), null);

      expect(picture.size.isEmpty, isFalse);
      picture.picture.dispose();
    });
  }

  for (final category in Category.values) {
    test('the ${category.label} picture is a small WebP image', () async {
      final data = await rootBundle.load(category.picture);
      final bytes = data.buffer.asUint8List();

      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
      expect(bytes.length, lessThan(120 * 1024));
    });
  }

  test('there is an avatar for each of the 8 players', () {
    expect(AppAssets.animals.toSet(), hasLength(8));
  });
}
