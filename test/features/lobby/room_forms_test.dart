import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/services/game_service.dart';

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
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Create Room'));
    }

    testWidgets('shows the practice mode note', (tester) async {
      await openCreateRoom(tester);
      expect(find.textContaining('Practice mode'), findsOneWidget);
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
      await goToHome(tester);
      await tapAndSettle(tester, buttonLabelled('Join Room'));
    }

    testWidgets('shows the practice mode note', (tester) async {
      await openJoinRoom(tester);
      expect(find.textContaining('Practice mode'), findsOneWidget);
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
