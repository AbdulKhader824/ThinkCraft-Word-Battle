/// Rules for what players can type when creating or joining a room.
///
/// This file is plain Dart with no Flutter imports, so the same rules are
/// easy to test and can be matched by the server later.
abstract final class RoomInputRules {
  static const minNameLength = 2;
  static const maxNameLength = 12;
  static const roomCodeLength = 6;
  static const minPlayers = 2;
  static const maxPlayers = 8;

  /// Letters and numbers that are hard to confuse: no I, O, 0 or 1.
  static const roomCodeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final _validName = RegExp(r'^[\p{L}\p{M}\p{N} ]+$', unicode: true);
  static final _extraSpaces = RegExp(r'\s+');

  /// Removes spaces at the ends and collapses repeated spaces inside.
  static String cleanName(String name) {
    return name.trim().replaceAll(_extraSpaces, ' ');
  }

  /// Returns a friendly error message, or null when the name is fine.
  static String? validateName(String? name) {
    final cleaned = cleanName(name ?? '');
    final length = cleaned.runes.length;

    if (length == 0) return 'Type your name to play.';
    if (length < minNameLength) {
      return 'Use at least $minNameLength characters.';
    }
    if (length > maxNameLength) {
      return 'Use $maxNameLength characters or fewer.';
    }
    if (!_validName.hasMatch(cleaned)) {
      return 'Use only letters, numbers and spaces.';
    }
    return null;
  }

  /// Converts typed text to capitals and drops characters a code can't use.
  static String normalizeRoomCode(String code) {
    return code
        .toUpperCase()
        .split('')
        .where(roomCodeCharacters.contains)
        .join();
  }

  /// Returns a friendly error message, or null when the code is fine.
  static String? validateRoomCode(String? code) {
    final value = code ?? '';
    if (value.isEmpty) return 'Type the room code.';
    if (value.length != roomCodeLength) {
      return 'Room codes have $roomCodeLength characters.';
    }
    if (normalizeRoomCode(value) != value) {
      return 'Use capital letters and numbers 2 to 9.';
    }
    return null;
  }
}
