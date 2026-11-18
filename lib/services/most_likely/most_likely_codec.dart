import 'package:clock/clock.dart';

import '../../models/most_likely_room.dart';
import '../../models/player.dart';

/// Turns a [MostLikelyRoom] into JSON to send between phones, and back.
///
/// Timers travel as time left rather than a clock time, because phone
/// clocks differ; each phone turns the time left back into a deadline on
/// its own clock.
abstract final class MostLikelyCodec {
  static Map<String, Object?> encode(MostLikelyRoom room) {
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
        'questions': room.settings.questions,
        'topics': [for (final topic in room.settings.topics) topic.name],
      },
      'capacity': room.capacity,
      'phase': room.phase.name,
      'number': room.questionNumber,
      'topic': room.topic?.name,
      'question': room.question,
      'votes': room.votes,
      'voted': room.votedIds.toList(),
      'counts': room.voteCounts,
      'most': room.mostLikelyIds.toList(),
      'points': room.questionPoints,
      'roundPoints': room.roundPoints,
      'titles': room.titles,
      'msLeft': deadline?.difference(clock.now()).inMilliseconds,
      'ready': room.readyIds.toList(),
      'away': room.awayIds.toList(),
      'scores': room.scores,
    };
  }

  static MostLikelyRoom decode(Map<String, Object?> json) {
    final settings = json['settings']! as Map<String, Object?>;
    final msLeft = json['msLeft'] as int?;
    List<String> strings(Object? list) => [
      for (final value in list! as List<Object?>) value! as String,
    ];
    Map<String, T> mapOf<T>(Object? map, T Function(Object? value) read) => {
      for (final MapEntry(:key, :value)
          in (map! as Map<String, Object?>).entries)
        key: read(value),
    };
    int number(Object? value) => value! as int;

    return MostLikelyRoom(
      code: json['code']! as String,
      players: [
        for (final player in json['players']! as List<Object?>)
          _player(player! as Map<String, Object?>),
      ],
      settings: MostLikelySettings(
        questions: settings['questions']! as int,
        topics: {
          for (final name in strings(settings['topics']))
            MostLikelyTopic.values.byName(name),
        },
      ),
      capacity: json['capacity']! as int,
      phase: MostLikelyPhase.values.byName(json['phase']! as String),
      questionNumber: json['number']! as int,
      topic: switch (json['topic']) {
        final String name => MostLikelyTopic.values.byName(name),
        _ => null,
      },
      question: json['question'] as String?,
      votes: mapOf(json['votes'], (value) => value! as String),
      votedIds: strings(json['voted']).toSet(),
      voteCounts: mapOf(json['counts'], number),
      mostLikelyIds: strings(json['most']).toSet(),
      questionPoints: mapOf(json['points'], number),
      roundPoints: mapOf(json['roundPoints'], number),
      titles: mapOf(json['titles'], strings),
      deadline: msLeft == null
          ? null
          : clock.now().add(Duration(milliseconds: msLeft)),
      readyIds: strings(json['ready']).toSet(),
      awayIds: strings(json['away']).toSet(),
      scores: mapOf(json['scores'], number),
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
