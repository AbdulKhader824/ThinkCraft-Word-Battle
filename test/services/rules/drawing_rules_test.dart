import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/drawing_room.dart';
import 'package:thinkcraft_word_battle/models/sketch.dart';
import 'package:thinkcraft_word_battle/services/drawing_words.dart';
import 'package:thinkcraft_word_battle/services/rules/drawing_rules.dart';

void main() {
  group('points', () {
    test('guessers score by order: 10, 8, 6, 5, 4, then 3', () {
      expect(
        [
          for (var order = 0; order < 8; order++)
            DrawingRules.pointsForGuess(order),
        ],
        [10, 8, 6, 5, 4, 3, 3, 3],
      );
    });

    test('the drawer gets 3 for each guesser, plus 2 if everyone got it', () {
      expect(DrawingRules.drawerPoints(guessed: 3, guessers: 3), 11);
      expect(DrawingRules.drawerPoints(guessed: 1, guessers: 3), 3);
      expect(DrawingRules.drawerPoints(guessed: 0, guessers: 3), 0);
    });
  });

  group('guesses', () {
    test('ignore capitals, spaces and plurals', () {
      expect(DrawingRules.isCorrect('Cats', 'cat'), isTrue);
      expect(DrawingRules.isCorrect('  ICE   cream ', 'ice cream'), isTrue);
      expect(DrawingRules.isCorrect('dog', 'cat'), isFalse);
      expect(DrawingRules.isCorrect('', 'cat'), isFalse);
    });

    test('one letter off is close, for words of 4 letters or more', () {
      expect(DrawingRules.isClose('elephent', 'elephant'), isTrue);
      expect(DrawingRules.isClose('elephan', 'elephant'), isTrue);
      expect(DrawingRules.isClose('elephaant', 'elephant'), isTrue);
      expect(DrawingRules.isClose('elefent', 'elephant'), isFalse);
      expect(DrawingRules.isClose('cot', 'cat'), isFalse);
      expect(DrawingRules.isClose('elephant', 'elephant'), isFalse);
    });

    test('are cleaned and kept short', () {
      expect(DrawingRules.cleanGuess('  big   red  '), 'big red');
      expect(DrawingRules.cleanGuess('a' * 50).length, 30);
    });
  });

  group('hints', () {
    test('two for long words, one for 3 letters, none for shorter', () {
      expect(DrawingRules.hintCount('rocket'), 2);
      expect(DrawingRules.hintCount('cat'), 1);
      expect(DrawingRules.hintCount('ox'), 0);
    });

    test('the mask hides letters but keeps spaces', () {
      expect(DrawingRules.mask('ice cream', {}), '___ _____');
      expect(DrawingRules.mask('rocket', {0, 3}), 'r__k__');
    });
  });

  group('word list', () {
    final all = DrawingWords.forLevel(WordLevel.mixed);

    test('has no repeats', () {
      expect(all.toSet().length, all.length);
    });

    test('is lower case letters and spaces only', () {
      final pattern = RegExp(r'^[a-z]+( [a-z]+)*$');
      for (final word in all) {
        expect(pattern.hasMatch(word), isTrue, reason: word);
      }
    });

    test('picks three different unused words', () {
      final words = DrawingWords.pick(
        WordLevel.easy,
        Random(1),
        used: {'cat', 'dog'},
      );
      expect(words, hasLength(3));
      expect(words.toSet(), hasLength(3));
      expect(words, isNot(contains('cat')));
    });
  });

  group('sketch', () {
    test('applies strokes, undo and clear', () {
      final sketch = Sketch()
        ..apply(const StrokeStart(colour: 1, size: 0, points: [1, 2]))
        ..apply(const StrokeAdd([3, 4]))
        ..apply(const StrokeStart(colour: 2, size: 1, points: [5, 6]));
      expect(sketch.strokes, hasLength(2));
      expect(sketch.strokes.first.points, [1, 2, 3, 4]);

      sketch.apply(const SketchUndo());
      expect(sketch.strokes, hasLength(1));
      sketch.apply(const SketchClear());
      expect(sketch.isEmpty, isTrue);
    });

    test('changes travel as JSON', () {
      const op = StrokeStart(colour: 3, size: 2, points: [10, 20, 30, 40]);
      final back = SketchOp.fromJson(op.toJson()) as StrokeStart;
      expect(back.colour, 3);
      expect(back.points, [10, 20, 30, 40]);
    });
  });
}
