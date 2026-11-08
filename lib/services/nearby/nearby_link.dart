import 'dart:async';
import 'dart:convert';

/// One connection between the host's phone and a guest's phone, carrying
/// small JSON messages both ways.
///
/// The game code only uses this interface, so tests can join phones with
/// [MemoryLink.pair] instead of a real network.
abstract interface class NearbyLink {
  Stream<Map<String, Object?>> get messages;

  void send(Map<String, Object?> message);

  /// Completes when the connection ends, from either side.
  Future<void> get done;

  Future<void> close();
}

/// Waits for guests to connect to the host's phone.
abstract interface class NearbyServer {
  Stream<NearbyLink> get links;

  int get port;

  Future<void> close();
}

/// Connects to a host's phone.
typedef NearbyConnector = Future<NearbyLink> Function(String address, int port);

/// The port the host listens on, so a guest who types the address doesn't
/// also need a number.
const nearbyGamePort = 47530;

/// An in-memory [NearbyLink], for tests.
class MemoryLink implements NearbyLink {
  MemoryLink._();

  final _incoming = StreamController<Map<String, Object?>>.broadcast();
  final _done = Completer<void>();
  late MemoryLink _other;

  /// Two connected ends, like a guest's phone and the host's.
  static (MemoryLink, MemoryLink) pair() {
    final a = MemoryLink._();
    final b = MemoryLink._();
    a._other = b;
    b._other = a;
    return (a, b);
  }

  @override
  Stream<Map<String, Object?>> get messages => _incoming.stream;

  @override
  void send(Map<String, Object?> message) {
    if (_done.isCompleted || _other._done.isCompleted) return;
    // A round trip through JSON, as on a real network.
    final copy = jsonDecode(jsonEncode(message)) as Map<String, Object?>;
    scheduleMicrotask(() {
      if (!_other._incoming.isClosed) _other._incoming.add(copy);
    });
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    for (final end in [this, _other]) {
      if (!end._done.isCompleted) end._done.complete();
      scheduleMicrotask(end._incoming.close);
    }
  }

  /// Ends the connection without warning, like a phone leaving the Wi-Fi.
  void drop() => close();

  /// The other phone's end of this connection.
  MemoryLink get otherEnd => _other;

  /// Ends only this phone's side. The other phone notices later, if at
  /// all, as happens when one phone gives up on a connection first.
  void dropThisSide() {
    if (!_done.isCompleted) _done.complete();
    scheduleMicrotask(_incoming.close);
  }
}

/// An in-memory [NearbyServer], for tests. Guests connect with [connect].
class MemoryServer implements NearbyServer {
  final _links = StreamController<NearbyLink>.broadcast();
  bool _closed = false;

  /// The guests' ends of every connection so far, so tests can drop one.
  final guestLinks = <MemoryLink>[];

  @override
  Stream<NearbyLink> get links => _links.stream;

  @override
  int get port => nearbyGamePort;

  Future<NearbyLink> connect(String address, int port) async {
    if (_closed) throw StateError('Connection refused');
    final (guest, host) = MemoryLink.pair();
    guestLinks.add(guest);
    _links.add(host);
    return guest;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _links.close();
  }
}
