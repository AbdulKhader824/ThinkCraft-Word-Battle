import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in const [
    AppAssets.logo,
    AppAssets.tilo,
    ...AppAssets.animals,
  ]) {
    test('$path is bundled and parses as SVG', () async {
      final svg = await rootBundle.loadString(path);
      final picture = await vg.loadPicture(SvgStringLoader(svg), null);

      expect(picture.size.isEmpty, isFalse);
      picture.picture.dispose();
    });
  }

  test('there is an avatar for each of the 8 players', () {
    expect(AppAssets.animals.toSet(), hasLength(8));
  });
}
