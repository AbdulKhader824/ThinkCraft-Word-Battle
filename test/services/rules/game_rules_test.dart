import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/services/rules/game_rules.dart';

void main() {
  test('there are 26 letters', () {
    expect(GameRules.letters, hasLength(26));
  });

  test('the answer timer is 90 seconds', () {
    expect(GameRules.answerTime, const Duration(seconds: 90));
  });

  group('startsWithLetter', () {
    test('ignores capitals and surrounding spaces', () {
      expect(GameRules.startsWithLetter('Mango', 'M'), isTrue);
      expect(GameRules.startsWithLetter('mango', 'M'), isTrue);
      expect(GameRules.startsWithLetter('  mango ', 'm'), isTrue);
    });

    test('rejects a different first letter', () {
      expect(GameRules.startsWithLetter('Banana', 'M'), isFalse);
    });

    test('treats blank answers as empty, not wrong', () {
      expect(GameRules.startsWithLetter('', 'M'), isTrue);
      expect(GameRules.startsWithLetter('   ', 'M'), isTrue);
    });
  });
}
