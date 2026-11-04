import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/core/widgets/entrance.dart';
import 'package:thinkcraft_word_battle/core/widgets/outlined_text.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

double _opacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(Entrance),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

void main() {
  testWidgets('OutlinedText shows a single piece of text', (tester) async {
    await tester.pumpWidget(_host(const OutlinedText('Hello')));

    expect(find.text('Hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OutlinedText.rich reads as its plain text', (tester) async {
    await tester.pumpWidget(
      _host(
        const OutlinedText.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Hi'),
              TextSpan(text: '!'),
            ],
          ),
          dropShadow: true,
        ),
      ),
    );

    expect(find.text('Hi!', findRichText: true), findsOneWidget);
  });

  testWidgets('Entrance shows at once with reduced motion', (tester) async {
    await tester.pumpWidget(
      _host(const Entrance(index: 3, child: Text('Now')), reduceMotion: true),
    );

    expect(_opacity(tester), 1);
  });

  testWidgets('Entrance waits its turn, then fades in', (tester) async {
    await tester.pumpWidget(
      _host(
        const Entrance(
          index: 2,
          step: Duration(milliseconds: 100),
          fromScale: 0.5,
          child: Text('Later'),
        ),
      ),
    );

    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(Entrance.duration);
    expect(_opacity(tester), 1);
  });

  testWidgets('Entrance cancels its wait when removed', (tester) async {
    await tester.pumpWidget(
      _host(const Entrance(index: 5, child: Text('Gone'))),
    );
    await tester.pumpWidget(_host(const SizedBox()));

    // A pending timer would fail the test here.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gone'), findsNothing);
  });
}
