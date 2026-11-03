import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/widgets/game_button.dart';
import 'package:thinkcraft_word_battle/core/widgets/player_avatar.dart';
import 'package:thinkcraft_word_battle/features/lobby/ready_badge.dart';

import '../../fakes.dart';
import '../../helpers.dart';

Future<FakeGameService> _openLobby(
  WidgetTester tester, {
  required bool amHost,
  bool everyoneReady = true,
  bool iAmReady = true,
  Size size = const Size(360, 800),
}) async {
  final service = FakeGameService(
    fakeLobby(
      players: [
        fakePlayer(
          amHost ? localId : 'host',
          name: amHost ? 'Sam' : 'Luna',
          isHost: true,
        ),
        fakePlayer('bot', name: 'Kai', isReady: everyoneReady),
        if (!amHost) fakePlayer(localId, name: 'Sam', isReady: iAmReady),
      ],
    ),
  );
  await pumpGame(tester, service: service, size: size);
  await tester.pumpAndSettle();
  return service;
}

GameButton _button(WidgetTester tester, String label) {
  return tester.widget<GameButton>(find.widgetWithText(GameButton, label));
}

void main() {
  testWidgets('shows the room, the players and the practice label', (
    tester,
  ) async {
    await _openLobby(tester, amHost: true);

    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
    expect(find.textContaining('Practice mode'), findsOneWidget);
    expect(find.byType(PlayerAvatar), findsNWidgets(2));
  });

  testWidgets('marks the host and the local player', (tester) async {
    await _openLobby(tester, amHost: false);

    expect(find.text('Host'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('shows who is ready and who is waiting', (tester) async {
    await _openLobby(tester, amHost: true, everyoneReady: false);

    expect(find.byType(ReadyBadge), findsNWidgets(2));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
  });

  testWidgets('the host starts once everyone is ready', (tester) async {
    final service = await _openLobby(tester, amHost: true);

    await tapAndSettle(tester, find.text('Start Game'));

    expect(service.calls, contains('startRound'));
  });

  testWidgets('the host cannot start while someone is waiting', (tester) async {
    await _openLobby(tester, amHost: true, everyoneReady: false);

    expect(_button(tester, 'Start Game').onPressed, isNull);
    expect(find.textContaining('Waiting for 1 player'), findsOneWidget);
  });

  testWidgets('only the host sees Start Game', (tester) async {
    await _openLobby(tester, amHost: false, iAmReady: false);

    expect(find.text('Start Game'), findsNothing);
    expect(find.text("I'm Ready"), findsOneWidget);
  });

  testWidgets('a guest can get ready', (tester) async {
    final service = await _openLobby(tester, amHost: false, iAmReady: false);

    await tapAndSettle(tester, find.text("I'm Ready"));

    expect(service.calls, contains('setReady true'));
  });

  testWidgets('a ready guest can change their mind', (tester) async {
    final service = await _openLobby(tester, amHost: false);

    await tapAndSettle(tester, find.text('Not Ready'));

    expect(service.calls, contains('setReady false'));
  });

  testWidgets('8 players fit on a small phone', (tester) async {
    final service = FakeGameService(
      fakeLobby(
        players: [
          fakePlayer(localId, name: 'Abdul Khader', isHost: true),
          for (var index = 1; index < 8; index++)
            fakePlayer('bot$index', name: 'LongNamePlay'),
        ],
      ),
    );

    await pumpGame(tester, service: service, size: const Size(320, 568));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerAvatar), findsNWidgets(8));
  });

  group('leaving', () {
    testWidgets('the phone back button asks first, and can be cancelled', (
      tester,
    ) async {
      final service = await _openLobby(tester, amHost: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave the game?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Keep Playing'));

      expect(find.text('Leave the game?'), findsNothing);
      expect(service.calls, isNot(contains('leaveRoom')));
      expect(currentRoute(tester), AppRoutes.lobby);
    });

    testWidgets('confirming leaves the room and returns home', (tester) async {
      final service = await _openLobby(tester, amHost: true);

      await tapAndSettle(tester, find.byTooltip('Back'));
      await tapAndSettle(tester, find.text('Leave Game'));

      expect(service.calls, contains('leaveRoom'));
      expect(currentRoute(tester), AppRoutes.home);
    });
  });
}
