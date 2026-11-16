import 'dart:async';

import 'package:thinkcraft_word_battle/services/online/relay.dart';

/// A pretend relay server in memory, which behaves like the real one in
/// `server/`: rooms by code, keys to come back, refusals and drops.
class MemoryRelay {
  final _rooms = <String, _MemoryRoom>{};
  var _keys = 0;

  /// When false, phones can't reach the relay at all.
  bool reachable = true;

  /// Every address phones have opened, in order.
  final opened = <Uri>[];

  /// The guests' connections, oldest first, so tests can drop one.
  final guestSockets = <MemoryRelaySocket>[];

  MemoryRelaySocket? hostSocket(String code) => _rooms[code]?.host;

  bool hasRoom(String code) => _rooms.containsKey(code);

  int guestCount(String code) => _rooms[code]?.guests.length ?? 0;

  Future<RelaySocket> open(Uri uri) async {
    if (!reachable) throw StateError('No internet');
    opened.add(uri);
    final socket = MemoryRelaySocket._(this);
    final query = uri.queryParameters;
    final code = query['code'] ?? '';
    final game = query['game'] ?? '';
    switch (uri.pathSegments.last) {
      case 'host':
        _openHost(socket, code, game, query['key']);
      case 'join':
        _join(socket, code, game);
      default:
        socket._end(RelayCode.badRequest);
    }
    return socket;
  }

  /// The room's host didn't come back in time.
  void hostTimesOut(String code) {
    final room = _rooms.remove(code);
    if (room == null) return;
    for (final guest in room.guests.values) {
      guest._end(RelayCode.hostLeft);
    }
  }

  void _openHost(
    MemoryRelaySocket socket,
    String code,
    String game,
    String? key,
  ) {
    if (key == null) {
      if (_rooms.containsKey(code)) return socket._end(RelayCode.codeTaken);
      final room = _rooms[code] = _MemoryRoom(code, game, 'key${++_keys}');
      return _attachHost(room, socket);
    }
    final room = _rooms[code];
    if (room == null) return socket._end(RelayCode.noRoom);
    if (room.key != key) return socket._end(RelayCode.wrongKey);
    _attachHost(room, socket);
  }

  void _attachHost(_MemoryRoom room, MemoryRelaySocket socket) {
    final old = room.host;
    room.host = socket;
    socket
      .._room = room
      .._deliver('o:${room.key}:${room.guests.keys.join(',')}');
    old?._end(RelayCode.replaced);
  }

  void _join(MemoryRelaySocket socket, String code, String game) {
    final room = _rooms[code];
    if (room == null) return socket._end(RelayCode.noRoom);
    if (room.game != game) return socket._end(RelayCode.wrongGame);
    if (room.guests.length >= 10) return socket._end(RelayCode.roomFull);
    final id = ++room.lastId;
    room.guests[id] = socket;
    guestSockets.add(socket);
    socket
      .._room = room
      .._guestId = id
      .._deliver('ready');
    room.host?._deliver('j:$id');
  }

  void _fromPhone(MemoryRelaySocket socket, String frame) {
    final room = socket._room;
    if (room == null) return;
    final id = socket._guestId;
    if (id != null) {
      if (room.guests[id] == socket) room.host?._deliver('m:$id:$frame');
      return;
    }
    if (room.host != socket) return;
    final rest = frame.substring(2);
    if (frame.startsWith('m:')) {
      final colon = rest.indexOf(':');
      room.guests[int.parse(rest.substring(0, colon))]?._deliver(
        rest.substring(colon + 1),
      );
    } else if (frame.startsWith('k:')) {
      room.guests.remove(int.parse(rest))?._end(RelayCode.normal);
    }
  }

  void _phoneGone(MemoryRelaySocket socket, {required bool saidGoodbye}) {
    final room = socket._room;
    if (room == null) return;
    final id = socket._guestId;
    if (id != null) {
      if (room.guests[id] != socket) return;
      room.guests.remove(id);
      room.host?._deliver('l:$id');
      return;
    }
    if (room.host != socket) return;
    room.host = null;
    if (saidGoodbye) {
      _rooms.remove(room.code);
      for (final guest in room.guests.values) {
        guest._end(RelayCode.normal);
      }
    }
  }
}

class _MemoryRoom {
  _MemoryRoom(this.code, this.game, this.key);

  final String code;
  final String game;
  final String key;
  MemoryRelaySocket? host;
  final guests = <int, MemoryRelaySocket>{};
  var lastId = 0;
}

/// One phone's connection to the [MemoryRelay].
class MemoryRelaySocket implements RelaySocket {
  MemoryRelaySocket._(this._relay);

  final MemoryRelay _relay;
  final _frames = StreamController<String>();
  final _done = Completer<void>();
  _MemoryRoom? _room;
  int? _guestId;
  int? _closeCode;
  bool _ended = false;

  /// Frames this phone has sent.
  final sent = <String>[];

  bool get isOpen => !_ended;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  void send(String frame) {
    if (!isOpen) return;
    sent.add(frame);
    scheduleMicrotask(() => _relay._fromPhone(this, frame));
  }

  @override
  Future<void> get done => _done.future;

  @override
  int? get closeCode => _closeCode;

  @override
  Future<void> close([int code = RelayCode.normal]) async {
    if (!isOpen) return;
    _relay._phoneGone(this, saidGoodbye: code == RelayCode.normal);
    _end(code);
  }

  /// The connection breaks without a goodbye, like losing signal.
  void drop() {
    if (!isOpen) return;
    _relay._phoneGone(this, saidGoodbye: false);
    _end(null);
  }

  void _deliver(String frame) {
    if (isOpen) _frames.add(frame);
  }

  /// Closes after the frames already sent, as a real socket does.
  void _end(int? code) {
    if (!isOpen) return;
    _ended = true;
    _closeCode = code;
    final ended = _frames.close();
    // A socket nobody listened to yet still ends.
    unawaited(
      Future.any([ended, Future<void>.delayed(Duration.zero)]).then((_) {
        if (!_done.isCompleted) _done.complete();
      }),
    );
  }
}
