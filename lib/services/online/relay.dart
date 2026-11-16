import 'dart:async';
import 'dart:convert';

import '../game_service.dart';
import '../nearby/nearby_link.dart';

// Online rooms. The game still runs on the host's phone, exactly as in a
// nearby room; only the connection changes. Instead of friends reaching
// the host's phone over Wi-Fi, every phone connects to the relay server
// (`server/` in this repository), which passes messages along by room
// code. [RelayServer] stands in for the Wi-Fi server on the host's phone,
// and [RelayGuestLink] for a friend's Wi-Fi connection, so the games'
// hosts and clients work unchanged. The frames are described in
// `server/README.md`.

/// One WebSocket to the relay, carrying text frames.
abstract interface class RelaySocket {
  Stream<String> get frames;

  void send(String frame);

  /// Completes when the connection ends, from either side.
  Future<void> get done;

  /// Why the relay closed the connection, once [done]; null if it just broke.
  int? get closeCode;

  Future<void> close([int code = RelayCode.normal]);
}

/// Opens a WebSocket to the relay. Phones use `openRelaySocket` from
/// `relay_platform.dart`; tests use a pretend relay.
typedef RelayOpener = Future<RelaySocket> Function(Uri uri);

/// The relay's close codes, as in `server/README.md`.
abstract final class RelayCode {
  static const normal = 1000;
  static const badRequest = 4000;
  static const codeTaken = 4001;
  static const serverFull = 4002;
  static const noRoom = 4003;
  static const roomFull = 4004;
  static const wrongGame = 4005;
  static const wrongKey = 4006;
  static const expired = 4007;
  static const hostLeft = 4008;
  static const replaced = 4009;
}

/// The relay turned a phone away, or couldn't be reached ([code] is null).
class RelayRefused implements Exception {
  const RelayRefused([this.code]);

  final int? code;

  /// The host's room code is already in use, so the app picks another.
  bool get codeTaken => code == RelayCode.codeTaken;

  /// What to tell the player.
  String get message => switch (code) {
    RelayCode.noRoom =>
      "There's no room with that code. Check it and try again.",
    RelayCode.roomFull => 'That room is full.',
    RelayCode.wrongGame => 'That code is for a different game.',
    RelayCode.badRequest => "That code doesn't look right.",
    RelayCode.serverFull =>
      'The online server is busy. Try again in a few minutes.',
    _ => "Couldn't reach the online server. Check your internet and try again.",
  };

  @override
  String toString() => message;
}

Uri _relayUri(Uri relay, String path, Map<String, String> query) =>
    relay.resolve(path).replace(queryParameters: query);

/// The host's side of an online room: works like the Wi-Fi server, but
/// friends arrive through the relay.
///
/// If the host's own connection drops (moving between Wi-Fi and mobile
/// data, a tunnel), it reconnects with the room's key, and friends stay
/// in the room. If it can't get back, [lost] completes.
class RelayServer implements NearbyServer {
  RelayServer._({
    required this._openSocket,
    required this.relay,
    required this.code,
    required this.game,
    required this.resumeTries,
    required this.resumeGap,
  });

  /// A free relay server sleeps when nobody is playing, and takes up to a
  /// minute to wake, so the first room waits that long.
  static const openTimeout = Duration(seconds: 75);

  /// Opens a room on the relay. Throws [RelayRefused], whose
  /// [RelayRefused.codeTaken] means trying again with another code.
  static Future<RelayServer> open({
    required RelayOpener openSocket,
    required Uri relay,
    required String code,
    required String game,
    Duration timeout = openTimeout,
    int resumeTries = 8,
    Duration resumeGap = const Duration(seconds: 2),
  }) async {
    final server = RelayServer._(
      openSocket: openSocket,
      relay: relay,
      code: code,
      game: game,
      resumeTries: resumeTries,
      resumeGap: resumeGap,
    );
    await server._connect(timeout: timeout);
    return server;
  }

  final RelayOpener _openSocket;
  final Uri relay;
  final String code;
  final String game;

  /// Tries at getting back after the host's connection drops. The relay
  /// keeps the room for 20 seconds.
  final int resumeTries;
  final Duration resumeGap;

  final _links = StreamController<NearbyLink>.broadcast();
  final _guests = <int, _HostSideLink>{};
  final _lost = Completer<void>();
  RelaySocket? _socket;
  String? _key;
  bool _closed = false;

  @override
  Stream<NearbyLink> get links => _links.stream;

  /// Online rooms have no port: friends join by code.
  @override
  int get port => 0;

  /// Completes if the connection to the relay is gone for good, without
  /// [close] being called. Every friend's connection has ended by then.
  Future<void> get lost => _lost.future;

  /// False while reconnecting after a drop.
  bool get isConnected => _socket != null;

  Future<void> _connect({required Duration timeout}) async {
    final uri = _relayUri(relay, 'host', {
      'code': code,
      'game': game,
      'key': ?_key,
    });
    final RelaySocket socket;
    try {
      socket = await _openSocket(uri).timeout(timeout);
    } on Object {
      throw const RelayRefused();
    }

    final opened = Completer<void>();
    final subscription = socket.frames.listen((frame) {
      if (opened.isCompleted) {
        if (identical(_socket, socket)) _handle(frame);
        return;
      }
      // First the relay says the room is open: o:<key>:<guest ids>.
      final parts = frame.split(':');
      if (parts.length != 3 || parts[0] != 'o') return;
      _key = parts[1];
      _socket = socket;
      _reconcile({for (final id in parts[2].split(',')) ?int.tryParse(id)});
      opened.complete();
    }, onError: (Object _) {});
    unawaited(
      socket.done.then((_) {
        unawaited(subscription.cancel());
        if (!opened.isCompleted) {
          opened.completeError(RelayRefused(socket.closeCode));
        } else if (identical(_socket, socket)) {
          _socket = null;
          unawaited(_resume());
        }
      }),
    );

    try {
      await opened.future.timeout(timeout);
    } on TimeoutException {
      unawaited(socket.close());
      throw const RelayRefused();
    }
  }

  void _handle(String frame) {
    if (frame.length < 3 || frame[1] != ':') return;
    final rest = frame.substring(2);
    switch (frame[0]) {
      case 'j':
        if (int.tryParse(rest) case final id?) _addGuest(id);
      case 'l':
        _guests.remove(int.tryParse(rest))?._end();
      case 'm':
        final colon = rest.indexOf(':');
        if (colon <= 0) return;
        final guest = _guests[int.tryParse(rest.substring(0, colon))];
        if (guest == null) return;
        try {
          final message = jsonDecode(rest.substring(colon + 1));
          if (message is Map<String, Object?>) guest._receive(message);
        } on FormatException {
          // Not a game message; ignored.
        }
    }
  }

  void _addGuest(int id) {
    if (_guests.containsKey(id) || _links.isClosed) return;
    final link = _HostSideLink(this, id);
    _guests[id] = link;
    _links.add(link);
  }

  /// After getting back, matches the friends to those still connected.
  void _reconcile(Set<int> ids) {
    for (final id in _guests.keys.toList()) {
      if (!ids.contains(id)) _guests.remove(id)!._end();
    }
    ids.forEach(_addGuest);
  }

  Future<void> _resume() async {
    for (var attempt = 0; attempt < resumeTries && !_closed; attempt++) {
      await Future<void>.delayed(resumeGap);
      if (_closed) return;
      try {
        await _connect(timeout: const Duration(seconds: 10));
        return;
      } on RelayRefused catch (refusal) {
        // The relay answered no (the room has gone): no point trying again.
        if (refusal.code != null) break;
      }
    }
    if (!_closed) await _shutDown(lost: true);
  }

  void _send(String frame) => _socket?.send(frame);

  Future<void> _shutDown({required bool lost}) async {
    if (_closed) return;
    _closed = true;
    final socket = _socket;
    _socket = null;
    for (final guest in _guests.values.toList()) {
      guest._end();
    }
    _guests.clear();
    await _links.close();
    if (lost && !_lost.isCompleted) _lost.complete();
    // A proper goodbye, so the relay closes the room for everyone at once.
    await socket?.close();
  }

  @override
  Future<void> close() => _shutDown(lost: false);
}

/// One friend's connection, as the host's phone sees it.
class _HostSideLink implements NearbyLink {
  _HostSideLink(this._server, this.id);

  final RelayServer _server;
  final int id;

  // Holds messages until the host listens, so none are lost.
  final _incoming = StreamController<Map<String, Object?>>();
  final _done = Completer<void>();

  @override
  Stream<Map<String, Object?>> get messages => _incoming.stream;

  @override
  void send(Map<String, Object?> message) {
    if (!_done.isCompleted) _server._send('m:$id:${jsonEncode(message)}');
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    if (_done.isCompleted) return;
    _server._guests.remove(id);
    _server._send('k:$id');
    _end();
  }

  void _receive(Map<String, Object?> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  void _end() {
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}

/// A friend's connection to an online room, through the relay.
class RelayGuestLink implements NearbyLink {
  RelayGuestLink._(this._socket);

  /// Joins the room with [code]. Throws [JoinRefused] with words to show
  /// the player when the relay turns them away or can't be reached.
  static Future<NearbyLink> connect({
    required RelayOpener openSocket,
    required Uri relay,
    required String code,
    required String game,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _relayUri(relay, 'join', {'code': code, 'game': game});
    final RelaySocket socket;
    try {
      socket = await openSocket(uri).timeout(timeout);
    } on Object {
      throw JoinRefused(const RelayRefused().message);
    }

    final link = RelayGuestLink._(socket);
    final ready = Completer<void>();
    socket.frames.listen((frame) {
      if (!ready.isCompleted) {
        if (frame == 'ready') ready.complete();
        return;
      }
      try {
        final message = jsonDecode(frame);
        if (message is Map<String, Object?>) link._receive(message);
      } on FormatException {
        // Not a game message; ignored.
      }
    }, onError: (Object _) {});
    unawaited(
      socket.done.then((_) {
        if (!ready.isCompleted) {
          ready.completeError(
            JoinRefused(RelayRefused(socket.closeCode).message),
          );
        }
        link._end();
      }),
    );

    try {
      await ready.future.timeout(timeout);
    } on TimeoutException {
      unawaited(socket.close());
      throw JoinRefused(const RelayRefused().message);
    }
    return link;
  }

  final RelaySocket _socket;
  final _incoming = StreamController<Map<String, Object?>>();
  final _done = Completer<void>();

  @override
  Stream<Map<String, Object?>> get messages => _incoming.stream;

  @override
  void send(Map<String, Object?> message) {
    if (!_done.isCompleted) _socket.send(jsonEncode(message));
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() => _socket.close();

  void _receive(Map<String, Object?> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  void _end() {
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}

/// Connects a friend's phone to the online room with [code], for the
/// games' clients. They pass a Wi-Fi address and port, which online rooms
/// don't need, and call it again to reconnect after a drop.
NearbyConnector relayConnector({
  required RelayOpener openSocket,
  required Uri relay,
  required String code,
  required String game,
}) {
  return (_, _) => RelayGuestLink.connect(
    openSocket: openSocket,
    relay: relay,
    code: code,
    game: game,
  );
}
