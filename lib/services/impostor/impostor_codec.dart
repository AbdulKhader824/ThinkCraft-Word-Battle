import 'package:clock/clock.dart';

import '../../models/impostor_room.dart';
import '../../models/player.dart';

/// Turns an [ImpostorRoom] into JSON to send between phones, and back.
///
/// Timers travel as time left rather than a clock time, because phone
/// clocks differ; each phone turns the time left back into a deadline on
/// its own clock.
abstract final class ImpostorCodec {
  static Map<String, Object?> encode(ImpostorRoom room) {
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
        'seconds': room.settings.clueSeconds,
        'turns': room.settings.clueTurns,
        'topics': [for (final topic in room.settings.topics) topic.name],
      },
      'capacity': room.capacity,
      'phase': room.phase.name,
      'round': room.round,
      'topic': room.topic?.name,
      'word': room.word,
      'impostor': room.impostorId,
      'isImpostor': room.isImpostor,
      'clueOrder': room.clueOrder,
      'clueIndex': room.clueIndex,
      'votes': room.votes,
      'voted': room.votedIds.toList(),
      'choices': room.guessChoices,
      'guessed': room.guessedWord,
      'caught': room.caught,
      'end': room.roundEnd?.name,
      'points': room.roundPoints,
      'msLeft': deadline?.difference(clock.now()).inMilliseconds,
      'ready': room.readyIds.toList(),
      'away': room.awayIds.toList(),
      'scores': {
        for (final MapEntry(:key, :value) in room.scores.entries)
          key: [value.points, value.rightVotes, value.impostorPoints],
      },
    };
  }

  static ImpostorRoom decode(Map<String, Object?> json) {
    final settings = json['settings']! as Map<String, Object?>;
    final msLeft = json['msLeft'] as int?;
    List<String> strings(Object? list) => [
      for (final value in list! as List<Object?>) value! as String,
    ];
    Map<String, T> mapOf<T>(Object? map) => {
      for (final MapEntry(:key, :value)
          in (map! as Map<String, Object?>).entries)
        key: value as T,
    };

    return ImpostorRoom(
      code: json['code']! as String,
      players: [
        for (final player in json['players']! as List<Object?>)
          _player(player! as Map<String, Object?>),
      ],
      settings: ImpostorSettings(
        rounds: settings['rounds']! as int,
        clueSeconds: settings['seconds']! as int,
        clueTurns: settings['turns']! as int,
        topics: {
          for (final name in strings(settings['topics']))
            ImpostorTopic.values.byName(name),
        },
      ),
      capacity: json['capacity']! as int,
      phase: ImpostorPhase.values.byName(json['phase']! as String),
      round: json['round']! as int,
      topic: switch (json['topic']) {
        final String name => ImpostorTopic.values.byName(name),
        _ => null,
      },
      word: json['word'] as String?,
      impostorId: json['impostor'] as String?,
      isImpostor: json['isImpostor']! as bool,
      clueOrder: strings(json['clueOrder']),
      clueIndex: json['clueIndex']! as int,
      votes: mapOf<String>(json['votes']),
      votedIds: strings(json['voted']).toSet(),
      guessChoices: strings(json['choices']),
      guessedWord: json['guessed'] as String?,
      caught: json['caught'] as bool?,
      roundEnd: switch (json['end']) {
        final String name => RoundEnd.values.byName(name),
        _ => null,
      },
      roundPoints: mapOf<int>(json['points']),
      deadline: msLeft == null
          ? null
          : clock.now().add(Duration(milliseconds: msLeft)),
      readyIds: strings(json['ready']).toSet(),
      awayIds: strings(json['away']).toSet(),
      scores: {
        for (final MapEntry(:key, :value)
            in (json['scores']! as Map<String, Object?>).entries)
          key: _score(value! as List<Object?>),
      },
    );
  }

  static ImpostorScore _score(List<Object?> values) {
    return ImpostorScore(
      points: values[0]! as int,
      rightVotes: values[1]! as int,
      impostorPoints: values[2]! as int,
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
}
