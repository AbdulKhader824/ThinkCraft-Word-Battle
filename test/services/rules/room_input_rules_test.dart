import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/services/rules/room_input_rules.dart';

void main() {
  group('validateName', () {
    test('accepts names from 2 to 12 characters', () {
      expect(RoomInputRules.validateName('Al'), isNull);
      expect(RoomInputRules.validateName('Abdul Khader'), isNull);
    });

    test('accepts names in other alphabets', () {
      expect(RoomInputRules.validateName('അനു'), isNull);
      expect(RoomInputRules.validateName('José'), isNull);
    });

    test('rejects empty and blank names', () {
      expect(RoomInputRules.validateName(null), isNotNull);
      expect(RoomInputRules.validateName(''), isNotNull);
      expect(RoomInputRules.validateName('   '), isNotNull);
    });

    test('rejects names of the wrong length', () {
      expect(RoomInputRules.validateName('A'), isNotNull);
      expect(RoomInputRules.validateName('ABCDEFGHIJKLM'), isNotNull);
    });

    test('rejects symbols', () {
      expect(RoomInputRules.validateName('Sam!'), isNotNull);
      expect(RoomInputRules.validateName('<Sam>'), isNotNull);
    });

    test('counts the cleaned name, not extra spaces', () {
      expect(RoomInputRules.validateName('  Sam     Lee  '), isNull);
    });
  });

  test('cleanName trims and collapses spaces', () {
    expect(RoomInputRules.cleanName('  Sam     Lee  '), 'Sam Lee');
  });

  group('normalizeRoomCode', () {
    test('converts to capitals', () {
      expect(RoomInputRules.normalizeRoomCode('abc234'), 'ABC234');
    });

    test('removes confusing and unsupported characters', () {
      expect(RoomInputRules.normalizeRoomCode('a-i o0 1b'), 'AB');
    });
  });

  group('validateRoomCode', () {
    test('accepts a 6-character code', () {
      expect(RoomInputRules.validateRoomCode('ABC234'), isNull);
    });

    test('rejects empty codes', () {
      expect(RoomInputRules.validateRoomCode(null), isNotNull);
      expect(RoomInputRules.validateRoomCode(''), isNotNull);
    });

    test('rejects codes of the wrong length', () {
      expect(RoomInputRules.validateRoomCode('ABC23'), isNotNull);
      expect(RoomInputRules.validateRoomCode('ABC2345'), isNotNull);
    });

    test('rejects confusing characters', () {
      expect(RoomInputRules.validateRoomCode('ABCDE1'), isNotNull);
      expect(RoomInputRules.validateRoomCode('ABCDEO'), isNotNull);
    });
  });

  test('the player limits match the spec', () {
    expect(RoomInputRules.minPlayers, 2);
    expect(RoomInputRules.maxPlayers, 8);
  });
}
