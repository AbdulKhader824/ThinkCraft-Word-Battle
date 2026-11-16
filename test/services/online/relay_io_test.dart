import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/online/relay.dart';
import 'package:thinkcraft_word_battle/services/online/relay_io.dart';

/// A tiny WebSocket server that acts like a relay behind a proxy that
/// drops close frames (as Render's does): it says `x:<code>` and then
/// never closes.
Future<HttpServer> _proxyThatDropsCloses(List<String> sayFirst) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    sayFirst.forEach(socket.add);
    socket.listen((_) {});
  });
  return server;
}

void main() {
  test('a refusal said as text ends the connection with its code', () async {
    final server = await _proxyThatDropsCloses(['x:4003']);
    addTearDown(() => server.close(force: true));

    await expectLater(
      RelayGuestLink.connect(
        openSocket: openRelaySocket,
        relay: Uri.parse('ws://127.0.0.1:${server.port}/'),
        code: 'ZZZ999',
        game: 'word_battle',
        timeout: const Duration(seconds: 5),
      ),
      throwsA(
        isA<JoinRefused>().having(
          (e) => e.message,
          'message',
          contains("There's no room with that code"),
        ),
      ),
    );
  });

  test('frames before the goodbye still arrive', () async {
    final server = await _proxyThatDropsCloses(['hello', 'x:1000']);
    addTearDown(() => server.close(force: true));

    final socket = await openRelaySocket(
      Uri.parse('ws://127.0.0.1:${server.port}/'),
    );
    final frames = <String>[];
    socket.frames.listen(frames.add);
    await socket.done.timeout(const Duration(seconds: 5));
    expect(frames, ['hello']);
    expect(socket.closeCode, RelayCode.normal);
  });
}
