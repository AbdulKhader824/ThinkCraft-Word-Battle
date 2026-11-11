import 'dart:async';

import '../../models/drawing_room.dart';
import '../../models/sketch.dart';
import '../game_service.dart';
import '../nearby/nearby_link.dart';
import 'drawing_codec.dart';
import 'drawing_engine.dart';
import 'drawing_service.dart';

/// Runs a Guess the Drawing room on the host's phone: guests connect
/// through [server], their moves go into [engine], and each guest gets
/// their own view of the room and every stroke of the drawing.
class DrawingHost {
  DrawingHost({required this.engine, required this.server});

  final DrawingEngine engine;
  final NearbyServer server;

  /// Each connected guest phone, and which player it is.
  final _guests = <NearbyLink, String>{};
  final _batchers = <NearbyLink, InkBatcher>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    _subscriptions
      ..add(server.links.listen(_accept))
      ..add(engine.roomChanges.listen(_sendToAll))
      ..add(engine.inkChanges.listen(_passOnInk));
  }

  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final link in _guests.keys.toList()) {
      link.send({'t': DrawingMessage.closed});
      _forget(link);
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
        final playerId = _guests[link];
        _forget(link);
        // The host may only notice an old connection died after the player
        // is already back on a new one. Then they aren't away.
        if (playerId != null && !_guests.containsValue(playerId)) {
          engine.setAway(playerId, away: true);
        }
      }),
    );
  }

  void _forget(NearbyLink link) {
    _guests.remove(link);
    _batchers.remove(link)?.dispose();
  }

  void _handle(NearbyLink link, Map<String, Object?> message) {
    final playerId = _guests[link];
    if (playerId == null) {
      _greet(link, message);
      return;
    }
    try {
      switch (message['t']) {
        case DrawingMessage.ready:
          engine.setReady(playerId, message['value'] == true);
        case DrawingMessage.choose:
          engine.chooseWord(playerId, message['index']! as int);
        case DrawingMessage.ink:
          final turnId = message['turn']! as int;
          for (final op in message['ops']! as List<Object?>) {
            engine.draw(
              playerId,
              turnId,
              SketchOp.fromJson(op! as Map<String, Object?>),
            );
          }
        case DrawingMessage.guess:
          engine.guess(playerId, message['text']! as String);
        case DrawingMessage.next:
          engine.nextRound(playerId);
        case DrawingMessage.leave:
          _forget(link);
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
    if (message['game'] != DrawingMessage.game) {
      _refuse(link, 'That room is playing a different game.');
      return;
    }
    if (message['v'] != DrawingMessage.version) {
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
      if (message['t'] == DrawingMessage.rejoin) {
        playerId = message['id']! as String;
        if (!engine.hasPlayer(playerId)) {
          throw const JoinRefused('The game went on without you.');
        }
        final stale = [
          for (final MapEntry(key: old, value: id) in _guests.entries)
            if (id == playerId && old != link) old,
        ];
        for (final old in stale) {
          _forget(old);
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
      _batchers[link] = InkBatcher(
        send: (turnId, ops) => link.send({
          't': DrawingMessage.ink,
          'turn': turnId,
          'ops': [for (final op in ops) op.toJson()],
        }),
      );
      link.send({'t': DrawingMessage.welcome, 'id': playerId});
      _sendRoom(link, playerId);
      // The drawing so far, for a player coming back mid-turn.
      final current = engine.room;
      if (current != null && current.phase == DrawingPhase.drawing) {
        link.send({
          't': DrawingMessage.sketch,
          'turn': current.turnId,
          'strokes': engine.sketch.toJson(),
        });
      }
    } on JoinRefused catch (error) {
      _refuse(link, error.message);
    }
  }

  void _refuse(NearbyLink link, String reason) {
    link.send({'t': DrawingMessage.refused, 'reason': reason});
    unawaited(link.close());
  }

  void _sendToAll(DrawingRoom? room) {
    for (final MapEntry(key: link, value: playerId)
        in _guests.entries.toList()) {
      if (room == null) {
        link.send({'t': DrawingMessage.closed});
        _forget(link);
        unawaited(link.close());
      } else if (!engine.hasPlayer(playerId)) {
        // They didn't press Next Round in time, so they leave the room.
        link.send({'t': DrawingMessage.removed});
        _forget(link);
        unawaited(link.close());
      } else {
        // Strokes waiting to go belong before the room changes.
        _batchers[link]?.flush();
        _sendRoom(link, playerId);
      }
    }
  }

  void _sendRoom(NearbyLink link, String playerId) {
    final view = engine.roomFor(playerId);
    if (view == null) return;
    link.send({'t': DrawingMessage.room, 'room': DrawingCodec.encode(view)});
  }

  /// Sends each stroke to everyone but the player who drew it.
  void _passOnInk(InkEvent event) {
    for (final MapEntry(key: link, value: playerId) in _guests.entries) {
      if (playerId == event.authorId) continue;
      _batchers[link]?.add(event.turnId, event.op);
    }
  }
}
