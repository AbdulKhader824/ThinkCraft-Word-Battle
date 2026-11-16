import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/game_settings.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/models/room.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';
import 'package:thinkcraft_word_battle/services/nearby/nearby_discovery.dart';

import '../../fakes.dart';
import '../../helpers.dart';

final _fields = find.byType(TextFormField);

String _fieldText(WidgetTester tester, int index) {
  return tester.widget<TextFormField>(_fields.at(index)).controller!.text;
}

GameService _service(WidgetTester tester) => gameService(tester);

void main() {
  group('Create Room', () {
    Future<void> openCreateRoom(WidgetTester tester) async {
      await pumpGame(tester);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));
    }

    testWidgets('answers are checked with smart check by default', (
      tester,
    ) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(find.text('How are answers checked?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdWith!.answerCheck, AnswerCheck.smart);
    });

    testWidgets('the host can choose how answers are checked', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      final auto = find.byKey(const ValueKey('check-auto'));
      await tester.ensureVisible(auto);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, auto);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdWith!.answerCheck, AnswerCheck.auto);
    });

    testWidgets('practice asks how smart the bots are, Medium first', (
      tester,
    ) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(find.text('How smart are the bots?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdWith!.botLevel, BotLevel.medium);
    });

    testWidgets('the host can choose hard bots', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      final hard = find.byKey(const ValueKey('bot-level-hard'));
      await tester.ensureVisible(hard);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, hard);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdWith!.botLevel, BotLevel.hard);
    });

    testWidgets('a nearby room only asks about bots when it has them', (
      tester,
    ) async {
      await openCreateRoom(tester);

      await tapAndSettle(tester, find.byKey(const ValueKey('mode-nearby')));
      expect(find.text('How smart are the bots?'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('fill-with-bots')));
      await tapAndSettle(tester, find.byKey(const ValueKey('fill-with-bots')));
      expect(find.text('How smart are the bots?'), findsOneWidget);
    });

    testWidgets('starts on practice, with the practice note', (tester) async {
      await openCreateRoom(tester);
      expect(find.textContaining('Practice:'), findsOneWidget);
      expect(find.text('How many players?'), findsOneWidget);
    });

    testWidgets('friends nearby asks the room size and about bots', (
      tester,
    ) async {
      await openCreateRoom(tester);

      await tapAndSettle(tester, find.byKey(const ValueKey('mode-nearby')));

      expect(find.text('How many players?'), findsOneWidget);
      expect(find.text('Fill empty seats with bots'), findsOneWidget);
      expect(find.text('Play with just the friends who join.'), findsOneWidget);
      expect(find.textContaining('same Wi-Fi'), findsWidgets);
    });

    testWidgets('a nearby room keeps its size and bot choice', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, find.byKey(const ValueKey('mode-nearby')));
      await tester.ensureVisible(find.byKey(const ValueKey('player-count-6')));
      await tapAndSettle(tester, find.byKey(const ValueKey('player-count-6')));
      await tester.ensureVisible(find.byKey(const ValueKey('fill-with-bots')));
      await tapAndSettle(tester, find.byKey(const ValueKey('fill-with-bots')));
      expect(
        find.text('Seats nobody takes get a bot when you start.'),
        findsOneWidget,
      );
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdPlayerCount, 6);
      expect(service.createdFillWithBots, isTrue);
    });

    testWidgets('practice never passes the bot switch on', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(find.text('Fill empty seats with bots'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdFillWithBots, isFalse);
    });

    testWidgets('an online room is created as online', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, find.byKey(const ValueKey('mode-online')));
      expect(find.textContaining('Friends anywhere can join'), findsOneWidget);
      // Bots can fill an online room's empty seats, as in a nearby one.
      expect(find.text('Fill empty seats with bots'), findsOneWidget);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdMode, RoomMode.online);
    });

    testWidgets('a nearby room is created as nearby', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, find.byKey(const ValueKey('mode-nearby')));
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(service.createdMode, RoomMode.nearby);
    });

    testWidgets('an empty name shows an error and creates nothing', (
      tester,
    ) async {
      await openCreateRoom(tester);

      await tapAndSettle(tester, buttonLabelled('Create Room'));

      expect(find.text('Type your name to play.'), findsOneWidget);
      expect(_service(tester).room, isNull);
    });

    testWidgets('a valid form creates the room and opens the Lobby', (
      tester,
    ) async {
      await openCreateRoom(tester);

      await tester.enterText(_fields.first, '  Sam  ');
      await tapAndSettle(tester, find.byKey(const ValueKey('player-count-6')));
      await tapAndSettle(tester, buttonLabelled('Create Room'));

      final room = _service(tester).room!;
      expect(room.host.name, 'Sam');
      expect(room.players, hasLength(6));
      expect(currentRoute(tester), AppRoutes.lobby);
    });

    testWidgets('offers exactly 2 to 8 players', (tester) async {
      await openCreateRoom(tester);

      expect(find.byKey(const ValueKey('player-count-1')), findsNothing);
      for (var count = 2; count <= 8; count++) {
        expect(find.byKey(ValueKey('player-count-$count')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('player-count-9')), findsNothing);
    });

    testWidgets('limits names to 12 characters', (tester) async {
      await openCreateRoom(tester);

      await tester.enterText(_fields.first, 'ABCDEFGHIJKLMNOP');
      await tester.pump();

      expect(_fieldText(tester, 0), 'ABCDEFGHIJKL');
    });
  });

  group('Join Room', () {
    Future<void> openJoinRoom(WidgetTester tester) async {
      await pumpGame(tester);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));
    }

    testWidgets('an online room is joined by its code alone', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      await tapAndSettle(tester, find.byKey(const ValueKey('mode-online')));
      // No Wi-Fi rooms or addresses online.
      expect(find.text('Rooms nearby'), findsNothing);
      expect(find.textContaining("Can't see the room?"), findsNothing);
      expect(find.text("Type your friend's room code"), findsOneWidget);

      await tester.enterText(_fields.at(0), 'Sam');
      await tester.enterText(_fields.at(1), 'abc234');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(service.calls, ['joinRoom ABC234']);
      expect(service.joinedOnline, isTrue);
      expect(service.joinedAddress, isNull);
    });

    testWidgets('looks for rooms nearby', (tester) async {
      final finder = FakeRoomFinder();
      await pumpGame(tester, finder: finder);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.text('Rooms nearby'), findsOneWidget);
      expect(find.textContaining('Looking for rooms'), findsOneWidget);
      expect(finder.listening, isTrue);

      await tapAndSettle(tester, find.byTooltip('Back'));
      expect(finder.listening, isFalse, reason: 'stops when the screen closes');
    });

    testWidgets('a room found nearby joins with one tap', (tester) async {
      final service = FakeGameService(null);
      final finder = FakeRoomFinder();
      await pumpGame(tester, service: service, finder: finder);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      finder.show(const [
        NearbyRoomInfo(
          code: 'K7PQ2M',
          hostName: 'Ammu',
          hostAvatar: 2,
          playerCount: 3,
          address: '192.168.43.1',
          port: 47530,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text("Ammu's room"), findsOneWidget);
      expect(find.text('K7PQ2M · 3 players'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Sam');
      await tapAndSettle(tester, find.byKey(const ValueKey('nearby-K7PQ2M')));

      expect(service.calls, contains('joinRoom K7PQ2M'));
      expect(service.joinedAddress, '192.168.43.1');
    });

    testWidgets('the host address can be typed in', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      await tapAndSettle(tester, find.textContaining("Can't see the room?"));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), 'ABC234');
      await tester.enterText(fields.at(2), '192.168.43.1');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(service.joinedAddress, '192.168.43.1');
    });

    testWidgets('a wrong address is caught before joining', (tester) async {
      final service = FakeGameService(null);
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      await tapAndSettle(tester, find.textContaining("Can't see the room?"));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), 'ABC234');
      await tester.enterText(fields.at(2), '192.168');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.textContaining('should look like'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('a refused join explains why', (tester) async {
      final service = FakeGameService(null)
        ..refuseJoin = const JoinRefused('That room is full.');
      await pumpGame(tester, service: service);
      await goToWordBattle(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), 'ABC234');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.text("Couldn't join"), findsOneWidget);
      expect(find.text('That room is full.'), findsOneWidget);
      await tapAndSettle(tester, buttonLabelled('OK'));
      expect(find.text("Couldn't join"), findsNothing);
    });

    testWidgets('empty fields show errors and join nothing', (tester) async {
      await openJoinRoom(tester);

      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.text('Type your name to play.'), findsOneWidget);
      expect(find.text('Type the room code.'), findsOneWidget);
      expect(_service(tester).room, isNull);
    });

    testWidgets('a short code is rejected', (tester) async {
      await openJoinRoom(tester);

      await tester.enterText(_fields.at(0), 'Sam');
      await tester.enterText(_fields.at(1), 'ABC');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(find.text('Room codes have 6 characters.'), findsOneWidget);
      expect(_service(tester).room, isNull);
    });

    testWidgets('typed codes become capitals and drop bad characters', (
      tester,
    ) async {
      await openJoinRoom(tester);

      await tester.enterText(_fields.at(1), 'ab-c2o34xyz');
      await tester.pump();

      expect(_fieldText(tester, 1), 'ABC234');
    });

    testWidgets('a valid form joins the room and opens the Lobby', (
      tester,
    ) async {
      await openJoinRoom(tester);

      await tester.enterText(_fields.at(0), 'Sam');
      await tester.enterText(_fields.at(1), 'abc234');
      await tapAndSettle(tester, buttonLabelled('Join Room'));

      expect(_service(tester).room!.code, 'ABC234');
      expect(currentRoute(tester), AppRoutes.lobby);
    });
  });
}
