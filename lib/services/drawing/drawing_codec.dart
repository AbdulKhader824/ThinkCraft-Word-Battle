import 'package:clock/clock.dart';

import '../../models/drawing_room.dart';
import '../../models/player.dart';

/// Turns a [DrawingRoom] into JSON to send between phones, and back.
///
/// Timers travel as time left rather than a clock time, because phone
/// clocks differ; each phone turns the time left back into a deadline on
/// its own clock.
abstract final class DrawingCodec {
  static Map<String, Object?> encode(DrawingRoom room) {
    final deadline = room.deadline;
    return {
      'code': room.code,
      'players': [
        for (final player in room.players)
          {
            'id': player.id,
            'name': player.name,
            'avatar': player.avatarIndex,
            'host': player.isHost,
            'ready': player.isReady,
          },
      ],
      'settings': {
        'rounds': room.settings.rounds,
        'seconds': room.settings.drawSeconds,
        'level': room.settings.wordLevel.name,
      },
      'capacity': room.capacity,
      'phase': room.phase.name,
      'round': room.round,
      'turn': room.turnId,
      'turnInRound': room.turnInRound,
      'turnsInRound': room.turnsInRound,
      'drawer': room.drawerId,
      'choices': room.choices,
      'word': room.word,
      'mask': room.wordMask,
      'msLeft': deadline?.difference(clock.now()).inMilliseconds,
      'guessed': room.guessedIds,
      'feed': [
        for (final entry in room.feed)
          {'id': entry.playerId, 'kind': entry.kind.name, 'text': entry.text},
      ],
      'turnPoints': room.turnPoints,
      'turnEnd': room.turnEnd?.name,
      'ready': room.readyIds.toList(),
      'away': room.awayIds.toList(),
      'scores': {
        for (final MapEntry(:key, :value) in room.scores.entries)
          key: [value.points, value.stars],
      },
    };
  }

  static DrawingRoom decode(Map<String, Object?> json) {
    final settings = json['settings']! as Map<String, Object?>;
    final msLeft = json['msLeft'] as int?;
    List<String> strings(Object? list) => [
      for (final value in list! as List<Object?>) value! as String,
    ];

    return DrawingRoom(
      code: json['code']! as String,
      players: [
        for (final player in json['players']! as List<Object?>)
          _player(player! as Map<String, Object?>),
      ],
      settings: DrawingSettings(
        rounds: settings['rounds']! as int,
        drawSeconds: settings['seconds']! as int,
        wordLevel: WordLevel.values.byName(settings['level']! as String),
      ),
      capacity: json['capacity']! as int,
      phase: DrawingPhase.values.byName(json['phase']! as String),
      round: json['round']! as int,
      turnId: json['turn']! as int,
      turnInRound: json['turnInRound']! as int,
      turnsInRound: json['turnsInRound']! as int,
      drawerId: json['drawer'] as String?,
      choices: strings(json['choices']),
      word: json['word'] as String?,
      wordMask: json['mask'] as String?,
      deadline: msLeft == null
          ? null
          : clock.now().add(Duration(milliseconds: msLeft)),
      guessedIds: strings(json['guessed']),
      feed: [
        for (final entry in json['feed']! as List<Object?>)
          _entry(entry! as Map<String, Object?>),
      ],
      turnPoints: {
        for (final MapEntry(:key, :value)
            in (json['turnPoints']! as Map<String, Object?>).entries)
          key: value! as int,
      },
      turnEnd: switch (json['turnEnd']) {
        final String name => TurnEnd.values.byName(name),
        _ => null,
      },
      readyIds: strings(json['ready']).toSet(),
      awayIds: strings(json['away']).toSet(),
      scores: {
        for (final MapEntry(:key, :value)
            in (json['scores']! as Map<String, Object?>).entries)
          key: DrawingScore(
            points: (value! as List<Object?>)[0]! as int,
            stars: (value as List<Object?>)[1]! as int,
          ),
      },
    );
  }

  static Player _player(Map<String, Object?> json) {
    return Player(
      id: json['id']! as String,
      name: json['name']! as String,
      avatarIndex: json['avatar']! as int,
      isHost: json['host']! as bool,
      isReady: json['ready']! as bool,
    );
  }

  static FeedEntry _entry(Map<String, Object?> json) {
    return FeedEntry(
      playerId: json['id']! as String,
      kind: FeedKind.values.byName(json['kind']! as String),
      text: json['text']! as String,
    );
  }
}
