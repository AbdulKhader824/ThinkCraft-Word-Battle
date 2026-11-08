import 'dart:async';

/// A room some phone on this network is announcing.
class NearbyRoomInfo {
  const NearbyRoomInfo({
    required this.code,
    required this.hostName,
    required this.hostAvatar,
    required this.playerCount,
    this.capacity,
    required this.address,
    required this.port,
  });

  final String code;
  final String hostName;
  final int hostAvatar;
  final int playerCount;

  /// How many players the room holds. Null from an older version of the
  /// app, which didn't say.
  final int? capacity;

  /// True when nobody else can join.
  bool get isFull => capacity != null && playerCount >= capacity!;

  /// The host phone's address on the network.
  final String address;
  final int port;

  /// The announcement the host sends. The address isn't in it: the
  /// receiving phone knows where the message came from.
  Map<String, Object?> toBeacon() => {
    'app': beaconApp,
    'v': beaconVersion,
    'code': code,
    'host': hostName,
    'avatar': hostAvatar,
    'players': playerCount,
    'seats': capacity,
    'port': port,
  };

  /// Reads an announcement, or returns null if it isn't one of ours.
  static NearbyRoomInfo? fromBeacon(Object? json, String address) {
    if (json is! Map<String, Object?>) return null;
    if (json['app'] != beaconApp || json['v'] != beaconVersion) return null;
    final code = json['code'];
    final host = json['host'];
    final avatar = json['avatar'];
    final players = json['players'];
    final port = json['port'];
    if (code is! String ||
        host is! String ||
        avatar is! int ||
        players is! int ||
        port is! int) {
      return null;
    }
    return NearbyRoomInfo(
      code: code,
      hostName: host,
      hostAvatar: avatar,
      playerCount: players,
      capacity: json['seats'] as int?,
      address: address,
      port: port,
    );
  }

  static const beaconApp = 'playpals';
  static const beaconVersion = 1;

  /// The port announcements are sent to.
  static const beaconPort = 47531;
}

/// Finds rooms being announced on the same Wi-Fi or hotspot.
abstract interface class RoomFinder {
  /// The rooms heard recently. A room drops off a few seconds after its
  /// announcements stop, such as when its game starts.
  Stream<List<NearbyRoomInfo>> get rooms;

  List<NearbyRoomInfo> get current;

  /// Starts listening. Safe to call again while already listening.
  Future<void> start();

  Future<void> stop();
}

/// Announces this phone's room so others can find it.
abstract interface class RoomBeacon {
  /// Announces [describe]'s room about once a second until [stop].
  Future<void> start(NearbyRoomInfo Function() describe);

  Future<void> stop();
}

/// A [RoomFinder] that never finds anything, for platforms without a
/// local network, such as the web version.
class NoRoomFinder implements RoomFinder {
  @override
  Stream<List<NearbyRoomInfo>> get rooms => const Stream.empty();

  @override
  List<NearbyRoomInfo> get current => const [];

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
