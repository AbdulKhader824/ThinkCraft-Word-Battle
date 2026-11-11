import 'dart:async';

import '../../models/category.dart';
import '../../models/room.dart';
import '../../models/vote.dart';
import '../game_service.dart';
import '../local_game_service.dart';
import 'nearby_link.dart';
import 'room_codec.dart';

/// The kinds of message phones send each other.
abstract final class NearbyMessage {
  // Guest to host.
  static const join = 'join';
  static const rejoin = 'rejoin';
  static const ready = 'ready';
  static const letter = 'letter';
  static const answer = 'answer';
  static const submit = 'submit';
  static const vote = 'vote';
  static const next = 'next';
  static const leave = 'leave';

  // Host to guest.
  static const welcome = 'welcome';
  static const refused = 'refused';
  static const room = 'room';
  static const closed = 'closed';
  static const removed = 'removed';

  /// Raised if the message format ever changes, so old and new versions of
  /// the app don't misunderstand each other.
  static const version = 1;
}

/// Runs a nearby room on the host's phone: guests connect through
/// [server], and their moves go into the host's copy of the game,
/// [engine]. Every change is sent to each guest as they may see it.
class NearbyHost {
  NearbyHost({required this.engine, required this.server});

  final LocalGameService engine;
  final NearbyServer server;

  /// Each connected guest phone, and which player it is.
  final _guests = <NearbyLink, String>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    _subscriptions
      ..add(server.links.listen(_accept))
      ..add(engine.roomChanges.listen(_sendToAll));
  }

  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final link in _guests.keys.toList()) {
      link.send({'t': NearbyMessage.closed});
      await link.close();
    }
    _guests.clear();
    await server.close();
  }

  void _accept(NearbyLink link) {
    final subscription = link.messages.listen(
      (message) => _handle(link, message),
    );
    unawaited(
      link.done.then((_) {
        subscription.cancel();
        final playerId = _guests.remove(link);
        // The host may only notice an old connection died after the player
        // is already back on a new one. Then they aren't away.
        if (playerId != null && !_guests.containsValue(playerId)) {
          engine.setAway(playerId, away: true);
        }
      }),
    );
  }

  void _handle(NearbyLink link, Map<String, Object?> message) {
    final playerId = _guests[link];
    if (playerId == null) {
      _greet(link, message);
      return;
    }

    try {
      switch (message['t']) {
        case NearbyMessage.ready:
          engine.setReadyFor(playerId, message['value'] == true);
        case NearbyMessage.letter:
          engine.selectLetterFor(playerId, message['letter']! as String);
        case NearbyMessage.answer:
          engine.updateAnswerFor(
            playerId,
            Category.values.byName(message['category']! as String),
            message['text']! as String,
          );
        case NearbyMessage.submit:
          engine.submitAnswersFor(playerId);
        case NearbyMessage.vote:
          engine.castVoteFor(
            playerId,
            message['item']! as String,
            VoteChoice.values.byName(message['choice']! as String),
          );
        case NearbyMessage.next:
          engine.nextRoundFor(playerId);
        case NearbyMessage.leave:
          _guests.remove(link);
          engine.removePlayer(playerId);
          unawaited(link.close());
      }
    } on Object {
      // A late or doubled tap, such as voting twice, changes nothing. The
      // guest gets the current room again so their screen catches up.
      _send(link, playerId, engine.room);
    }
  }

  /// The first message from a new connection: a new player joining, or a
  /// player coming back after their connection dropped.
  void _greet(NearbyLink link, Map<String, Object?> message) {
    final room = engine.room;
    // Another game's phone, such as Guess the Drawing, says which game it
    // is. Word Battle phones don't.
    if (message['game'] != null) {
      _refuse(link, 'That room is playing a different game.');
      return;
    }
    if (message['v'] != NearbyMessage.version) {
      _refuse(link, 'Update the app so you can join this room.');
      return;
    }
    if (room == null) {
      _refuse(link, 'That room has closed.');
      return;
    }
    if (message['code'] != room.code) {
      _refuse(link, 'That room code is not right.');
      return;
    }

    try {
      final String playerId;
      if (message['t'] == NearbyMessage.rejoin) {
        playerId = message['id']! as String;
        if (!engine.hasPlayer(playerId)) {
          throw const JoinRefused('The game went on without you.');
        }
        // Their old connection is finished with, even if this phone
        // hasn't noticed it dying yet.
        final stale = [
          for (final MapEntry(key: old, value: id) in _guests.entries)
            if (id == playerId && old != link) old,
        ];
        for (final old in stale) {
          _guests.remove(old);
          unawaited(old.close());
        }
        engine.setAway(playerId, away: false);
      } else {
        playerId = engine.addPlayer(
          name: message['name']! as String,
          avatarIndex: message['avatar']! as int,
        );
      }
      _guests[link] = playerId;
      link.send({'t': NearbyMessage.welcome, 'id': playerId});
      _send(link, playerId, engine.room);
    } on JoinRefused catch (error) {
      _refuse(link, error.message);
    }
  }

  void _refuse(NearbyLink link, String reason) {
    link.send({'t': NearbyMessage.refused, 'reason': reason});
    unawaited(link.close());
  }

  void _sendToAll(Room? room) {
    for (final MapEntry(key: link, value: playerId)
        in _guests.entries.toList()) {
      if (room == null) {
        link.send({'t': NearbyMessage.closed});
        _guests.remove(link);
        unawaited(link.close());
      } else if (!engine.hasPlayer(playerId)) {
        // They didn't press Next Round in time, so they leave the room.
        link.send({'t': NearbyMessage.removed});
        _guests.remove(link);
        unawaited(link.close());
      } else {
        _send(link, playerId, room);
      }
    }
  }

  void _send(NearbyLink link, String playerId, Room? room) {
    if (room == null) return;
    final view = engine.roomFor(playerId);
    if (view == null) return;
    link.send({'t': NearbyMessage.room, 'room': RoomCodec.encode(view)});
  }
}
