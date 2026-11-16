import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/services/impostor/app_impostor_service.dart';
import 'package:thinkcraft_word_battle/services/impostor/impostor_engine.dart';
import 'package:thinkcraft_word_battle/services/online/online_rooms.dart';
import 'package:thinkcraft_word_battle/services/online/relay.dart';

import '../../fakes.dart';
import '../../helpers.dart';
import '../../memory_relay.dart';

/// Lets the pretend relay's messages arrive until [done].
Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var tries = 0; tries < 50 && !done(); tries++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('an online Impostor room: a call note, waking, then sharing', (
    tester,
  ) async {
    final relay = MemoryRelay();
    // The relay is asleep until the test wakes it.
    final awake = Completer<void>();
    Future<RelaySocket> openSocket(Uri uri) async {
      await awake.future;
      return relay.open(uri);
    }

    final service = AppImpostorService(
      engine: ImpostorEngine(random: Random(3)),
      finder: FakeRoomFinder(),
      beacon: FakeRoomBeacon(),
      startServer: () => throw StateError('No Wi-Fi in this test'),
      connect: (_, _) => throw StateError('No Wi-Fi in this test'),
      findAddress: () async => null,
      online: OnlineRooms(
        openSocket: openSocket,
        relay: Uri.parse('wss://relay.example'),
        random: Random(1),
      ),
    );
    final shared = <String>[];
    await pumpGame(tester, impostor: service, shared: shared);
    await goToHome(tester);
    await openRoute(tester, AppRoutes.impostor);
    await tapAndSettle(tester, buttonLabelled('Create Room'));

    await tester.enterText(find.byType(TextFormField).first, 'Sam');
    await tapAndSettle(tester, find.byKey(const ValueKey('mode-online')));
    expect(find.textContaining('voice call'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi'), findsNothing);

    await tapAndSettle(tester, buttonLabelled('Create Room'));
    expect(find.textContaining('can take up to a minute'), findsOneWidget);
    expect(buttonLabelled('Opening...'), findsOneWidget);

    awake.complete();
    await _waitFor(
      tester,
      () => currentRoute(tester) == AppRoutes.impostorLobby,
    );
    await tester.pumpAndSettle();
    final code = service.room!.code;
    expect(relay.hasRoom(code), isTrue);
    expect(find.text(code), findsOneWidget);
    expect(find.textContaining('Online room'), findsOneWidget);
    expect(find.textContaining('voice call'), findsOneWidget);
    expect(find.textContaining('Host address'), findsNothing);

    await tapAndSettle(tester, buttonLabelled('Share code'));
    expect(shared.single, contains(code));
    expect(shared.single, contains('The Impostor'));

    await tester.runAsync(service.leaveRoom);
    await tester.pumpAndSettle();
  });
}
