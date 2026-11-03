import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/theme/app_colors.dart';
import 'package:thinkcraft_word_battle/core/widgets/game_button.dart';
import 'package:thinkcraft_word_battle/core/widgets/player_avatar.dart';
import 'package:thinkcraft_word_battle/features/validation/validation_screen.dart';
import 'package:thinkcraft_word_battle/models/answer_group.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/models/vote.dart';

import '../../fakes.dart';
import '../../helpers.dart';

const _mango = BallotItem(
  id: 'food:mango',
  category: Category.food,
  text: 'Mango',
);
const _moose = BallotItem(
  id: 'animal:moose',
  category: Category.animal,
  text: 'Moose',
);

Future<FakeGameService> _open(
  WidgetTester tester, {
  List<BallotItem> ballot = const [_mango, _moose],
  Map<String, VoteChoice> myVotes = const {},
  Size size = const Size(360, 800),
}) async {
  final service = FakeGameService(
    fakeVotingRoom(ballot: ballot, myVotes: myVotes),
  );
  await pumpGame(tester, service: service, size: size);
  await tester.pumpAndSettle();
  await tester.pump(ValidationScreen.tapGuard);
  return service;
}

int _voteCount(FakeGameService service) {
  return service.calls.where((call) => call.startsWith('castVote')).length;
}

void main() {
  testWidgets('shows the answer and its category', (tester) async {
    await _open(tester);

    expect(find.text('Mango'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Answer 1 of 2'), findsOneWidget);
  });

  testWidgets('never shows who wrote the answer', (tester) async {
    await _open(tester);

    expect(find.text('Sam'), findsNothing);
    expect(find.text('Luna'), findsNothing);
    expect(find.text('Kai'), findsNothing);
    expect(find.byType(PlayerAvatar), findsNothing);
  });

  testWidgets('Valid is green and Invalid is red', (tester) async {
    await _open(tester);

    final valid = tester.widget<GameButton>(
      find.widgetWithText(GameButton, 'Valid'),
    );
    final invalid = tester.widget<GameButton>(
      find.widgetWithText(GameButton, 'Invalid'),
    );

    expect(valid.style.face, AppColors.valid);
    expect(invalid.style.face, AppColors.invalid);
  });

  testWidgets('tapping Valid casts a valid vote', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Valid'));

    expect(service.calls, contains('castVote food:mango valid'));
  });

  testWidgets('tapping Invalid casts an invalid vote', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Invalid'));

    expect(service.calls, contains('castVote food:mango invalid'));
  });

  testWidgets('players can skip an answer', (tester) async {
    final service = await _open(tester);

    await tapAndSettle(tester, find.text('Not sure? Skip this one'));

    expect(service.calls, contains('castVote food:mango skip'));
  });

  testWidgets('a double tap only votes once', (tester) async {
    final service = await _open(tester);

    await tester.tap(find.text('Valid'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Valid'));
    await tester.pumpAndSettle();

    expect(_voteCount(service), 1);
  });

  testWidgets('a double tap cannot vote on the next answer by accident', (
    tester,
  ) async {
    final service = await _open(tester);

    await tester.tap(find.text('Valid'));
    service.emit(
      fakeVotingRoom(
        ballot: const [_mango, _moose],
        myVotes: {_mango.id: VoteChoice.valid},
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Moose'), findsOneWidget);

    await tester.tap(find.text('Valid'));
    await tester.pumpAndSettle();
    expect(service.calls, isNot(contains('castVote animal:moose valid')));

    await tester.pump(ValidationScreen.tapGuard);
    await tester.tap(find.text('Valid'));
    await tester.pumpAndSettle();
    expect(service.calls, contains('castVote animal:moose valid'));
  });

  testWidgets('moves to the next answer after a vote', (tester) async {
    await _open(tester, myVotes: {_mango.id: VoteChoice.valid});

    expect(find.text('Mango'), findsNothing);
    expect(find.text('Moose'), findsOneWidget);
    expect(find.text('Answer 2 of 2'), findsOneWidget);
  });

  testWidgets('shows a waiting message once finished', (tester) async {
    await _open(
      tester,
      myVotes: {_mango.id: VoteChoice.valid, _moose.id: VoteChoice.skip},
    );

    expect(find.text('Counting the votes...'), findsOneWidget);
    expect(find.text('Valid'), findsNothing);
  });

  testWidgets('shows the waiting message with nothing to vote on', (
    tester,
  ) async {
    await _open(tester, ballot: const []);

    expect(find.text('Counting the votes...'), findsOneWidget);
  });

  testWidgets('fits on a small phone', (tester) async {
    await _open(tester, size: const Size(320, 568));

    expect(find.text('Valid'), findsOneWidget);
  });

  testWidgets('the back button asks before leaving', (tester) async {
    await _open(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave the game?'), findsOneWidget);
    expect(currentRoute(tester), AppRoutes.validation);
  });
}
