import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'nearby_discovery.dart';
import 'nearby_link.dart';

// The real local-network pieces, for phones. The web version uses
// nearby_web.dart instead, because browsers can't open these connections.

Future<NearbyServer> startNearbyServer() => WebSocketServer.start();

Future<NearbyLink> connectNearby(String address, int port) {
  return WebSocketLink.connect(address, port);
}

RoomFinder createRoomFinder() => UdpRoomFinder();

RoomBeacon createRoomBeacon() => UdpRoomBeacon();

/// This phone's address on the Wi-Fi or its own hotspot, for friends who
/// need to type it in. Null when it isn't on any local network.
Future<String?> localNetworkAddress() async {
  try {
    final addresses = [
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      ))
        for (final address in interface.addresses) address.address,
    ];
    // Home Wi-Fi and phone hotspots use these private ranges.
    for (final prefix in ['192.168.', '10.', '172.']) {
      for (final address in addresses) {
        if (address.startsWith(prefix)) return address;
      }
    }
    return addresses.isEmpty ? null : addresses.first;
  } on SocketException {
    return null;
  }
}

/// A [NearbyLink] over a WebSocket on the local network.
class WebSocketLink implements NearbyLink {
  WebSocketLink(this._socket) {
    // Checks the connection now and then, so a phone that vanishes (left
    // the Wi-Fi, battery died) is noticed. A phone gets 6 seconds to
    // answer each check, so a slow or battery-saving phone that pauses for
    // a moment isn't mistaken for one that left; a phone that really left
    // is noticed within about 12 seconds.
    _socket.pingInterval = const Duration(seconds: 6);
    _messages = _socket
        .where((data) => data is String)
        .map((data) => jsonDecode(data as String) as Map<String, Object?>)
        .handleError((Object _) {})
        .asBroadcastStream();
  }

  final WebSocket _socket;
  late final Stream<Map<String, Object?>> _messages;

  static Future<NearbyLink> connect(String address, int port) async {
    final socket = await WebSocket.connect('ws://$address:$port')
        .timeout(const Duration(seconds: 5));
    return WebSocketLink(socket);
  }

  @override
  Stream<Map<String, Object?>> get messages => _messages;

  @override
  void send(Map<String, Object?> message) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(jsonEncode(message));
    }
  }

  @override
  Future<void> get done => _socket.done.then((_) {}, onError: (Object _) {});

  @override
  Future<void> close() => _socket.close();
}

/// A [NearbyServer] that accepts WebSocket connections on every network
/// this phone is on, including its own hotspot.
class WebSocketServer implements NearbyServer {
  WebSocketServer._(this._server);

  final HttpServer _server;
  final _links = StreamController<NearbyLink>.broadcast();

  /// Listens on [nearbyGamePort], or any free port if that one is taken.
  static Future<WebSocketServer> start() async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, nearbyGamePort);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    final result = WebSocketServer._(server);
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        if (!result._links.isClosed) result._links.add(WebSocketLink(socket));
      } on Object {
        // A half-made connection is simply dropped.
      }
    });
    return result;
  }

  @override
  Stream<NearbyLink> get links => _links.stream;

  @override
  int get port => _server.port;

  @override
  Future<void> close() async {
    await _server.close(force: true);
    await _links.close();
  }
}

/// Listens for room announcements sent across the local network.
class UdpRoomFinder implements RoomFinder {
  /// A room is forgotten this long after its last announcement.
  static const _forgetAfter = Duration(seconds: 4);

  final _rooms = StreamController<List<NearbyRoomInfo>>.broadcast();
  final _seen = <String, (NearbyRoomInfo, DateTime)>{};
  RawDatagramSocket? _socket;
  Timer? _tidy;

  @override
  Stream<List<NearbyRoomInfo>> get rooms => _rooms.stream;

  @override
  List<NearbyRoomInfo> get current => [
    for (final (room, _) in _seen.values) room,
  ];

  /// Asks Android to pass on broadcast messages, which many phones drop
  /// to save battery. See MainActivity.kt.
  static const _wifi = MethodChannel('playpals/wifi');

  @override
  Future<void> start() async {
    if (_socket != null) return;
    try {
      await _wifi.invokeMethod<void>('listen');
    } on Object {
      // Not Android, or not available: broadcasts usually arrive anyway.
    }
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        NearbyRoomInfo.beaconPort,
        reuseAddress: true,
      );
      _socket = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        try {
          final json = jsonDecode(utf8.decode(datagram.data));
          final room = NearbyRoomInfo.fromBeacon(
            json,
            datagram.address.address,
          );
          if (room == null) return;
          _seen[room.code] = (room, DateTime.now());
          _emit();
        } on FormatException {
          // Not one of ours.
        }
      });
      _tidy = Timer.periodic(const Duration(seconds: 1), (_) {
        final before = _seen.length;
        _seen.removeWhere(
          (_, seen) => DateTime.now().difference(seen.$2) > _forgetAfter,
        );
        if (_seen.length != before) _emit();
      });
    } on SocketException {
      // No network to listen on. Typing the host's address still works.
    }
  }

  void _emit() {
    if (!_rooms.isClosed) _rooms.add(current);
  }

  @override
  Future<void> stop() async {
    _tidy?.cancel();
    _tidy = null;
    _socket?.close();
    _socket = null;
    _seen.clear();
    try {
      await _wifi.invokeMethod<void>('stopListening');
    } on Object {
      // Nothing was held.
    }
  }
}

/// Announces a room to every phone on the local network.
class UdpRoomBeacon implements RoomBeacon {
  static const _every = Duration(seconds: 1);

  RawDatagramSocket? _socket;
  Timer? _timer;

  @override
  Future<void> start(NearbyRoomInfo Function() describe) async {
    await stop();
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        ..broadcastEnabled = true;
      _socket = socket;
      _timer = Timer.periodic(_every, (_) => _announce(socket, describe()));
    } on SocketException {
      // Friends can still join by typing this phone's address.
    }
  }

  Future<void> _announce(RawDatagramSocket socket, NearbyRoomInfo room) async {
    final bytes = utf8.encode(jsonEncode(room.toBeacon()));
    for (final target in await _targets()) {
      try {
        socket.send(bytes, target, NearbyRoomInfo.beaconPort);
      } on SocketException {
        // That network may have just gone away.
      }
    }
  }

  /// The general broadcast address, plus each network's own, because a
  /// phone's hotspot doesn't always pass on the general one.
  Future<List<InternetAddress>> _targets() async {
    final targets = [InternetAddress('255.255.255.255')];
    try {
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length != 4) continue;
          targets.add(InternetAddress('${parts.take(3).join('.')}.255'));
        }
      }
    } on SocketException {
      // Fall back to the general broadcast only.
    }
    return targets;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}
