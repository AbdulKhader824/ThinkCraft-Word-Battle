import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/truth_or_dare_game.dart';
import 'rules/truth_or_dare_rules.dart';
import 'truth_or_dare_cards.dart';

/// The randomness Truth or Dare uses. Tests replace it with a seeded one.
final truthOrDareRandomProvider = Provider<Random>((ref) => Random());

/// The Truth or Dare game on this phone, or null when none is being
/// played. One phone, passed around, so it all lives here.
class TruthOrDareNotifier extends Notifier<TodGame?> {
  @override
  TodGame? build() => null;

  Random get _random => ref.read(truthOrDareRandomProvider);

  String _pick(TodLevel level, TodKind kind, Set<String> used) =>
      TruthOrDareCards.pick(level, kind, used, _random);

  void start(List<String> names, TodSettings settings) {
    state = TruthOrDareRules.start(names, settings, _random);
  }

  /// The same players and settings, from the start.
  void playAgain() {
    final game = state;
    if (game == null) return;
    start([for (final player in game.players) player.name], game.settings);
  }

  void choose(TodKind kind) =>
      _update((game) => TruthOrDareRules.choose(game, kind, _pick));

  void done() => _update((game) => TruthOrDareRules.done(game, _random));

  void skip() => _update((game) => TruthOrDareRules.skip(game, _random));

  void finish() => _update(TruthOrDareRules.finish);

  void clear() => state = null;

  void _update(TodGame Function(TodGame game) move) {
    final game = state;
    if (game != null) state = move(game);
  }
}

final truthOrDareProvider = NotifierProvider<TruthOrDareNotifier, TodGame?>(
  TruthOrDareNotifier.new,
);
