import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/truth_or_dare_game.dart';
import 'package:thinkcraft_word_battle/services/rules/rude_words.dart';
import 'package:thinkcraft_word_battle/services/rules/truth_or_dare_rules.dart';
import 'package:thinkcraft_word_battle/services/truth_or_dare_cards.dart';

/// A card picker that numbers its cards, so tests can tell them apart.
String Function(TodLevel, TodKind, Set<String>) _numbered() {
  var count = 0;
  return (level, kind, used) => '${kind.name} ${count++}';
}

TodGame _start(List<String> names, {int rounds = 3, int seed = 1}) =>
    TruthOrDareRules.start(names, TodSettings(rounds: rounds), Random(seed));

void main() {
  final random = Random(5);

  test('starting spins for the first player, with different faces', () {
    final game = _start(['Sam', 'Riya', 'Ali']);
    expect(game.phase, TodPhase.choose);
    expect(game.round, 1);
    expect(game.current, isNotNull);
    expect(game.takenThisRound, {game.current});
    expect(game.players.map((p) => p.avatarIndex).toSet(), hasLength(3));
    expect(game.players.every((p) => p.livesLeft == 3), isTrue);
    expect(() => _start(['Sam']), throwsArgumentError);
    expect(
      () => _start([for (var i = 0; i < 13; i++) 'P$i']),
      throwsArgumentError,
    );
  });

  test('everyone gets one turn a round, never twice in a row', () {
    var game = _start(['Sam', 'Riya', 'Ali', 'Zara'], rounds: 10);
    final pick = _numbered();
    int? last;
    for (var round = 1; round <= 10; round++) {
      final seen = <int>{};
      for (var turn = 0; turn < 4; turn++) {
        expect(game.round, round);
        expect(game.current, isNot(last));
        expect(seen.add(game.current!), isTrue);
        last = game.current;
        game = TruthOrDareRules.choose(game, TodKind.truth, pick);
        game = TruthOrDareRules.done(game, random);
      }
    }
    expect(game.phase, TodPhase.finished);
    expect(game.players.every((p) => p.points == 10), isTrue);
  });

  test('Done scores a point for a truth or a dare', () {
    var game = _start(['Sam', 'Riya']);
    final pick = _numbered();
    final first = game.current!;
    game = TruthOrDareRules.choose(game, TodKind.dare, pick);
    expect(game.phase, TodPhase.card);
    expect(game.kind, TodKind.dare);
    expect(game.card, 'dare 0');
    game = TruthOrDareRules.done(game, random);
    expect(game.players[first].dares, 1);
    expect(game.players[first].points, 1);
    expect(game.phase, TodPhase.choose);
    expect(game.current, isNot(first));
  });

  test('a card can\'t be swapped: choosing again changes nothing', () {
    var game = _start(['Sam', 'Riya']);
    final pick = _numbered();
    game = TruthOrDareRules.choose(game, TodKind.truth, pick);
    expect(game.card, 'truth 0');
    expect(TruthOrDareRules.choose(game, TodKind.dare, pick), same(game));
    expect(game.usedCards, {'truth 0'});
  });

  test('each Skip costs a life, and three skips put a player out', () {
    var game = _start(['Sam', 'Riya', 'Ali'], rounds: 10);
    final pick = _numbered();
    // Sam skips every turn; everyone else does theirs.
    while (!game.players[0].isOut) {
      game = TruthOrDareRules.choose(game, TodKind.truth, pick);
      game = game.current == 0
          ? TruthOrDareRules.skip(game, random)
          : TruthOrDareRules.done(game, random);
    }
    expect(game.players[0].skips, 3);
    expect(game.players[0].livesLeft, 0);
    expect(game.stillIn, [1, 2]);
    // Sam never gets another turn.
    for (var turn = 0; turn < 10 && game.phase != TodPhase.finished; turn++) {
      expect(game.current, isNot(0));
      game = TruthOrDareRules.choose(game, TodKind.dare, pick);
      game = TruthOrDareRules.done(game, random);
    }
  });

  test('the game ends when fewer than 2 players are left in', () {
    var game = _start(['Sam', 'Riya'], rounds: 10);
    final pick = _numbered();
    while (game.phase != TodPhase.finished) {
      game = TruthOrDareRules.choose(game, TodKind.truth, pick);
      game = TruthOrDareRules.skip(game, random);
    }
    // One of them ran out of lives, so the other can't play alone.
    expect(game.players.where((p) => p.isOut), hasLength(1));
    expect(game.card, isNull);
  });

  test('ending early, and moves that make no sense, change nothing', () {
    var game = _start(['Sam', 'Riya']);
    final pick = _numbered();
    // Done before a card is drawn does nothing.
    expect(TruthOrDareRules.done(game, random), same(game));
    expect(TruthOrDareRules.skip(game, random), same(game));
    game = TruthOrDareRules.finish(game);
    expect(game.phase, TodPhase.finished);
    expect(TruthOrDareRules.choose(game, TodKind.dare, pick), same(game));
  });

  test('winners, Bravest and Most Honest, sharing ties', () {
    final game = TodGame(
      settings: TodSettings(),
      phase: TodPhase.finished,
      players: const [
        TodPlayer(name: 'Sam', avatarIndex: 0, truths: 3, dares: 1),
        TodPlayer(name: 'Riya', avatarIndex: 1, truths: 1, dares: 3),
        TodPlayer(name: 'Ali', avatarIndex: 2, dares: 2, skips: 3),
      ],
    );
    expect(TruthOrDareRules.winners(game), [0, 1]);
    expect(TruthOrDareRules.bravest(game), [1]);
    expect(TruthOrDareRules.mostHonest(game), [0]);
    expect(game.players[2].isOut, isTrue);

    final nobody = TodGame(
      settings: TodSettings(),
      players: const [
        TodPlayer(name: 'Sam', avatarIndex: 0),
        TodPlayer(name: 'Riya', avatarIndex: 1),
      ],
    );
    expect(TruthOrDareRules.winners(nobody), isEmpty);
    expect(TruthOrDareRules.bravest(nobody), isEmpty);
  });

  group('cards', () {
    test('at least 60 in each deck, unique and kind', () {
      final all = <String>[];
      for (final level in [TodLevel.kids, TodLevel.teens]) {
        for (final kind in TodKind.values) {
          final deck = TruthOrDareCards.deck(level, kind);
          expect(deck.length, greaterThanOrEqualTo(60), reason: '$level $kind');
          all.addAll(deck);
        }
      }
      expect(all.toSet(), hasLength(all.length));
      for (final card in all) {
        expect(soundsRude(card), isFalse, reason: card);
        expect(card.trim(), card);
        expect(card, matches(RegExp(r'[.?!]"?$')), reason: card);
      }
    });

    test('Mix has both decks', () {
      expect(
        TruthOrDareCards.deck(TodLevel.mix, TodKind.dare).length,
        TruthOrDareCards.deck(TodLevel.kids, TodKind.dare).length +
            TruthOrDareCards.deck(TodLevel.teens, TodKind.dare).length,
      );
    });

    test('cards never repeat until the deck runs out', () {
      final random = Random(3);
      final used = <String>{};
      final size = TruthOrDareCards.deck(TodLevel.kids, TodKind.truth).length;
      for (var i = 0; i < size; i++) {
        final card = TruthOrDareCards.pick(
          TodLevel.kids,
          TodKind.truth,
          used,
          random,
        );
        expect(used.add(card), isTrue);
      }
      final again = TruthOrDareCards.pick(
        TodLevel.kids,
        TodKind.truth,
        used,
        random,
      );
      expect(used, contains(again));
    });
  });

  test('settings check their choices', () {
    expect(TodSettings().rounds, 5);
    expect(TodSettings().level, TodLevel.kids);
    expect(() => TodSettings(rounds: 4), throwsArgumentError);
  });
}
