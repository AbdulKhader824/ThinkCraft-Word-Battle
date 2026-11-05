import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/widgets/player_avatar.dart';

import '../../fakes.dart';
import '../../helpers.dart';

Finder _tile(String letter) => find.byKey(ValueKey('letter-$letter'));

InkWell _tileWidget(WidgetTester tester, String letter) {
  return tester.widget<InkWell>(_tile(letter));
}

Future<FakeGameService> _open(
  WidgetTester tester,
  FakeGameService service, {
  Size size = const Size(360, 800),
}) async {
  await pumpGame(tester, service: service, size: size);
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('shows all 26 letters', (tester) async {
    await _open(tester, FakeGameService(fakeLetterRoom(pickerId: localId)));

    for (final letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      expect(_tile(letter), findsOneWidget);
    }
  });

  testWidgets('tiles are big enough to tap, even at 320px', (tester) async {
    await _open(
      tester,
      FakeGameService(fakeLetterRoom(pickerId: localId)),
      size: const Size(320, 568),
    );

    expect(tester.getSize(_tile('A')).width, greaterThanOrEqualTo(56));
  });

  testWidgets('the picker can choose a letter', (tester) async {
    final service = await _open(
      tester,
      FakeGameService(fakeLetterRoom(pickerId: localId)),
    );

    await tapAndSettle(tester, _tile('M'));

    expect(service.calls, contains('selectLetter M'));
  });

  testWidgets('other players see who is choosing, not the letters', (
    tester,
  ) async {
    await _open(tester, FakeGameService(fakeLetterRoom(pickerId: 'bot')));

    expect(find.text('Luna is choosing the letter...'), findsOneWidget);
    expect(find.byType(PlayerAvatar), findsOneWidget);
    expect(find.text('Get ready to think fast!'), findsOneWidget);
    expect(_tile('M'), findsNothing);
  });

  testWidgets('the mystery tile shows a question mark with reduced motion', (
    tester,
  ) async {
    await _open(tester, FakeGameService(fakeLetterRoom(pickerId: 'bot')));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('the mystery tile flicks through letters', (tester) async {
    await pumpGame(
      tester,
      service: FakeGameService(fakeLetterRoom(pickerId: 'bot')),
      reduceMotion: false,
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('?'), findsNothing);
    expect(find.text('Luna is choosing the letter...'), findsOneWidget);
  });

  testWidgets('used letters cannot be chosen', (tester) async {
    await _open(
      tester,
      FakeGameService(fakeLetterRoom(pickerId: localId, usedLetters: {'M'})),
    );

    expect(_tileWidget(tester, 'M').onTap, isNull);
    expect(_tileWidget(tester, 'N').onTap, isNotNull);
  });

  testWidgets('everyone sees the chosen letter', (tester) async {
    await _open(
      tester,
      FakeGameService(fakeLetterRoom(pickerId: 'bot', letter: 'Q')),
    );

    expect(find.text('The letter is Q!'), findsOneWidget);
    expect(_tile('A'), findsNothing);
  });
}
