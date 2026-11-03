import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room_entry.dart';

/// Holds the player's latest room choice until the Lobby exists to use it.
class RoomEntryNotifier extends Notifier<RoomEntry?> {
  @override
  RoomEntry? build() => null;

  void save(RoomEntry entry) => state = entry;
}

final roomEntryProvider = NotifierProvider<RoomEntryNotifier, RoomEntry?>(
  RoomEntryNotifier.new,
);
