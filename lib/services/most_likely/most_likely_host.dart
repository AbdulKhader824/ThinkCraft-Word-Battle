import 'dart:async';

import '../../models/most_likely_room.dart';
import '../game_service.dart';
import '../nearby/nearby_link.dart';
import 'most_likely_codec.dart';
import 'most_likely_engine.dart';
import 'most_likely_service.dart';

/// Runs a Most Likely To... room on the host's phone: guests connect
/// through [server], their moves go into [engine], and each guest gets
/// their own view of the room, so nobody sees who voted for whom.
class MostLikelyHost {
  MostLikelyHost({required this.engine, required this.server});

  final MostLikelyEngine engine;
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
      link.send({'t': MostLikelyMessage.closed});
      _guests.remove(link);
      await link.close();
    }
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
        case MostLikelyMessage.ready:
          engine.setReady(playerId, message['value'] == true);
        case MostLikelyMessage.vote:
          engine.vote(playerId, message['player']! as String);
        case MostLikelyMessage.next:
          engine.nextRound(playerId);
        case MostLikelyMessage.leave:
          _guests.remove(link);
          engine.removePlayer(playerId);
          unawaited(link.close());
      }
    } on Object {
      // A message that doesn't make sense changes nothing. The guest gets
      // the room again so their screen catches up.
      _sendRoom(link, playerId);
    }
  }

  /// The first message from a new connection: a new player joining, or a
  /// player coming back after their connection dropped.
  void _greet(NearbyLink link, Map<String, Object?> message) {
    final room = engine.room;
    if (message['game'] != MostLikelyMessage.game) {
      _refuse(link, 'That room is playing a different game.');
      return;
    }
    if (message['v'] != MostLikelyMessage.version) {
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
      if (message['t'] == MostLikelyMessage.rejoin) {
        playerId = message['id']! as String;
        if (!engine.hasPlayer(playerId)) {
          throw const JoinRefused('The game went on without you.');
        }
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
      link.send({'t': MostLikelyMessage.welcome, 'id': playerId});
      _sendRoom(link, playerId);
    } on JoinRefused catch (error) {
      _refuse(link, error.message);
    }
  }

  void _refuse(NearbyLink link, String reason) {
    link.send({'t': MostLikelyMessage.refused, 'reason': reason});
    unawaited(link.close());
  }

  void _sendToAll(MostLikelyRoom? room) {
    for (final MapEntry(key: link, value: playerId)
        in _guests.entries.toList()) {
      if (room == null) {
        link.send({'t': MostLikelyMessage.closed});
        _guests.remove(link);
        unawaited(link.close());
      } else if (!engine.hasPlayer(playerId)) {
        // They didn't press Next Round in time, so they leave the room.
        link.send({'t': MostLikelyMessage.removed});
        _guests.remove(link);
        unawaited(link.close());
      } else {
        _sendRoom(link, playerId);
      }
    }
  }

  void _sendRoom(NearbyLink link, String playerId) {
    final view = engine.roomFor(playerId);
    if (view == null) return;
    link.send({
      't': MostLikelyMessage.room,
      'room': MostLikelyCodec.encode(view),
    });
  }
}
