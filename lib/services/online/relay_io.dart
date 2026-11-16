import 'dart:async';
import 'dart:io';

import 'relay.dart';

// The real relay connection, for phones. The web version uses
// relay_web.dart instead.

Future<RelaySocket> openRelaySocket(Uri uri) async =>
    IoRelaySocket(await WebSocket.connect(uri.toString()));

/// A [RelaySocket] over a real WebSocket.
class IoRelaySocket implements RelaySocket {
  IoRelaySocket(this._socket) {
    // The relay checks too, but this notices a dead connection from the
    // phone's side, so a host can reconnect while the room still waits.
    _socket.pingInterval = const Duration(seconds: 10);
    _socket.listen(
      (data) {
        if (data is String && !_frames.isClosed) _frames.add(data);
      },
      onError: (Object _) {},
      // A WebSocket's own `done` waits for this side to close as well, so
      // the end of its messages is what marks the connection as over.
      onDone: () {
        unawaited(_frames.close());
        unawaited(_socket.close().then((_) {}, onError: (Object _) {}));
        if (!_done.isCompleted) _done.complete();
      },
      cancelOnError: false,
    );
  }

  final WebSocket _socket;
  // Holds frames until they're listened to, so none are lost.
  final _frames = StreamController<String>();
  final _done = Completer<void>();

  @override
  Stream<String> get frames => _frames.stream;

  @override
  void send(String frame) {
    if (_socket.readyState == WebSocket.open) _socket.add(frame);
  }

  @override
  Future<void> get done => _done.future;

  @override
  int? get closeCode => _socket.closeCode;

  @override
  Future<void> close([int code = RelayCode.normal]) =>
      _socket.close(code).then((_) {}, onError: (Object _) {});
}
