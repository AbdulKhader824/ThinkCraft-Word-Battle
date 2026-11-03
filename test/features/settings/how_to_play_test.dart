import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/app/router.dart';

import '../../helpers.dart';

void main() {
  Future<void> openHowToPlay(WidgetTester tester) async {
    await pumpGame(tester);
    await goToHome(tester);
    await tapAndSettle(tester, buttonLabelled('How to Play'));
  }

  testWidgets('Home opens How to Play, and Back returns', (tester) async {
    await openHowToPlay(tester);
    expect(currentRoute(tester), AppRoutes.howToPlay);

    await tapAndSettle(tester, find.byTooltip('Back'));
    expect(currentRoute(tester), AppRoutes.home);
  });

  testWidgets('explains all five steps', (tester) async {
    await openHowToPlay(tester);

    for (final step in [
      'Make a room',
      'Pick a letter',
      'Think fast!',
      'Vote',
      'Score points',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('describes the real scoring rules', (tester) async {
    await openHowToPlay(tester);

    final scoring = find.textContaining('Only you thought of it: 10 points');
    expect(scoring, findsOneWidget);
    expect(find.textContaining('5 each'), findsOneWidget);
    expect(find.textContaining('90 seconds'), findsOneWidget);
  });
}
