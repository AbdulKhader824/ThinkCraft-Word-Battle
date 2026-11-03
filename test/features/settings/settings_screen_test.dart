import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';
import 'package:thinkcraft_word_battle/core/constants/app_constants.dart';
import 'package:thinkcraft_word_battle/models/player_profile.dart';

import '../../fakes.dart';
import '../../helpers.dart';

final _nameField = find.byType(TextFormField).first;

Future<MemoryProfileStore> _openSettings(
  WidgetTester tester, {
  PlayerProfile saved = const PlayerProfile(),
}) async {
  final store = MemoryProfileStore(saved);
  await pumpGame(tester, profiles: store);
  await goToHome(tester);
  await tapAndSettle(tester, buttonLabelled('Settings'));
  return store;
}

void main() {
  testWidgets('Home opens Settings, and Back returns', (tester) async {
    await _openSettings(tester);
    expect(currentRoute(tester), AppRoutes.settings);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(currentRoute(tester), AppRoutes.home);
  });

  testWidgets('shows the saved name and character', (tester) async {
    await _openSettings(
      tester,
      saved: const PlayerProfile(name: 'Sam', avatarIndex: 3),
    );

    expect(find.text('Sam'), findsOneWidget);
    final cat = tester.getSemantics(find.byKey(const ValueKey('avatar-3')));
    expect(cat, isSemantics(isSelected: true));
  });

  testWidgets('saves a new name and character', (tester) async {
    final store = await _openSettings(tester);

    await tester.enterText(_nameField, '  Luna  ');
    await tapAndSettle(tester, find.byKey(const ValueKey('avatar-5')));
    await tapAndSettle(tester, find.text('Save'));

    expect(store.saved.name, 'Luna');
    expect(store.saved.avatarIndex, 5);
    expect(find.text('Saved!'), findsOneWidget);
  });

  testWidgets('rejects a bad name and saves nothing', (tester) async {
    final store = await _openSettings(tester);

    await tester.enterText(_nameField, 'L!');
    await tapAndSettle(tester, find.text('Save'));

    expect(find.text('Use only letters, numbers and spaces.'), findsOneWidget);
    expect(store.saved.name, isEmpty);
  });

  testWidgets('a blank name is allowed', (tester) async {
    final store = await _openSettings(
      tester,
      saved: const PlayerProfile(name: 'Sam'),
    );

    await tester.enterText(_nameField, '');
    await tapAndSettle(tester, find.text('Save'));

    expect(store.saved.name, isEmpty);
  });

  testWidgets('offers all eight characters, by name', (tester) async {
    await _openSettings(tester);

    for (var index = 0; index < PlayerProfile.avatarCount; index++) {
      final finder = find.byKey(ValueKey('avatar-$index'));
      expect(finder, findsOneWidget);
      expect(tester.getSemantics(finder).label, AppAssets.animalNames[index]);
    }
  });

  testWidgets('the saved name fills in Create Room', (tester) async {
    await pumpGame(
      tester,
      profiles: MemoryProfileStore(const PlayerProfile(name: 'Sam')),
    );
    await goToHome(tester);

    await tapAndSettle(tester, buttonLabelled('Create Room'));

    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('the saved name fills in Join Room', (tester) async {
    await pumpGame(
      tester,
      profiles: MemoryProfileStore(const PlayerProfile(name: 'Sam')),
    );
    await goToHome(tester);

    await tapAndSettle(tester, buttonLabelled('Join Room'));

    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('the game uses the chosen character and remembers the name', (
    tester,
  ) async {
    final store = MemoryProfileStore(const PlayerProfile(avatarIndex: 6));
    await pumpGame(tester, profiles: store);
    await goToHome(tester);

    await tapAndSettle(tester, buttonLabelled('Create Room'));
    await tester.enterText(find.byType(TextFormField).first, 'Kai');
    await tapAndSettle(tester, buttonLabelled('Create Room'));

    final room = gameService(tester).room!;
    expect(room.host.avatarIndex, 6);
    expect(
      room.players.where((player) => player.avatarIndex == 6),
      hasLength(1),
    );
    expect(store.saved.name, 'Kai');
    expect(store.saved.avatarIndex, 6);
  });
}
