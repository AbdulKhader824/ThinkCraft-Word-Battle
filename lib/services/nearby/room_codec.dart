import 'package:clock/clock.dart';

import '../../models/answer.dart';
import '../../models/answer_group.dart';
import '../../models/category.dart';
import '../../models/game_phase.dart';
import '../../models/game_settings.dart';
import '../../models/player.dart';
import '../../models/room.dart';
import '../../models/round.dart';
import '../../models/round_results.dart';
import '../../models/vote.dart';

/// Turns a [Room] into plain JSON-ready maps and back, to send it between
/// phones.
///
/// Times are sent as milliseconds left, not as clock times, because two
/// phones' clocks are rarely set exactly the same. Each phone turns the
/// time left back into a deadline on its own clock.
abstract final class RoomCodec {
  static Map<String, Object?> encode(Room room) {
    final round = room.round;
    return {
      'code': room.code,
      'mode': room.mode.name,
      'capacity': room.capacity,
      'bots': room.fillWithBots,
      'phase': room.phase.name,
      'settings': {
        'rounds': room.settings.rounds,
        'answerSeconds': room.settings.answerSeconds,
        'categories': [for (final c in room.settings.categories) c.name],
        'answerCheck': room.settings.answerCheck.name,
        'botLevel': room.settings.botLevel.name,
      },
      'players': [for (final player in room.players) _player(player)],
      'usedLetters': room.usedLetters.toList(),
      'scores': {
        for (final MapEntry(:key, :value) in room.scores.entries)
          key: _score(value),
      },
      'round': round == null ? null : _round(round),
    };
  }

  static Room decode(Map<String, Object?> json) {
    final settings = json['settings']! as Map<String, Object?>;
    final round = json['round'] as Map<String, Object?>?;
    return Room(
      code: json['code']! as String,
      mode: RoomMode.values.byName(json['mode']! as String),
      capacity: json['capacity'] as int? ?? 8,
      fillWithBots: json['bots'] as bool? ?? false,
      phase: GamePhase.values.byName(json['phase']! as String),
      settings: GameSettings(
        rounds: settings['rounds']! as int,
        answerSeconds: settings['answerSeconds']! as int,
        categories: [
          for (final name in settings['categories']! as List)
            Category.values.byName(name as String),
        ],
        answerCheck:
            AnswerCheck.values.asNameMap()[settings['answerCheck']] ??
            AnswerCheck.vote,
        // Rooms from an older app version don't say; theirs are Medium.
        botLevel:
            BotLevel.values.asNameMap()[settings['botLevel']] ??
            BotLevel.medium,
      ),
      players: [
        for (final player in json['players']! as List)
          _readPlayer(player as Map<String, Object?>),
      ],
      usedLetters: {for (final l in json['usedLetters']! as List) l as String},
      scores: {
        for (final MapEntry(:key, :value)
            in (json['scores']! as Map<String, Object?>).entries)
          key: _readScore(value! as Map<String, Object?>),
      },
      round: round == null ? null : _readRound(round),
    );
  }

  static Map<String, Object?> _player(Player player) => {
    'id': player.id,
    'name': player.name,
    'avatar': player.avatarIndex,
    'host': player.isHost,
    'bot': player.isBot,
    'ready': player.isReady,
  };

  static Player _readPlayer(Map<String, Object?> json) => Player(
    id: json['id']! as String,
    name: json['name']! as String,
    avatarIndex: json['avatar']! as int,
    isHost: json['host']! as bool,
    isBot: json['bot']! as bool,
    isReady: json['ready']! as bool,
  );

  static Map<String, Object?> _score(ScoreLine score) => {
    'answer': score.answerPoints,
    'votes': score.validationPoints,
  };

  static ScoreLine _readScore(Map<String, Object?> json) => ScoreLine(
    answerPoints: json['answer']! as int,
    validationPoints: json['votes']! as int,
  );

  static int? _msLeft(DateTime? deadline) {
    if (deadline == null) return null;
    final left = deadline.difference(clock.now()).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  static DateTime? _readDeadline(Object? msLeft) {
    if (msLeft == null) return null;
    return clock.now().add(Duration(milliseconds: msLeft as int));
  }

  static Map<String, Object?> _round(Round round) => {
    'number': round.number,
    'picker': round.pickerId,
    'letter': round.letter,
    'deadlineIn': _msLeft(round.deadline),
    'submitted': round.submittedPlayerIds.toList(),
    'answers': [
      for (final answer in round.answers)
        {
          'player': answer.playerId,
          'category': answer.category.name,
          'text': answer.text,
        },
    ],
    'ballot': [
      for (final item in round.ballot)
        {'id': item.id, 'category': item.category.name, 'text': item.text},
    ],
    'myVotes': {
      for (final MapEntry(:key, :value) in round.myVotes.entries)
        key: value.name,
    },
    'results': round.results == null ? null : _results(round.results!),
    'nextReady': round.nextRoundReadyIds.toList(),
    'nextDeadlineIn': _msLeft(round.nextRoundDeadline),
    'voteIn': _msLeft(round.voteDeadline),
    'voteTime': round.voteTime?.inMilliseconds,
    'voted': round.votedPlayerIds.toList(),
  };

  static Round _readRound(Map<String, Object?> json) {
    final results = json['results'] as Map<String, Object?>?;
    return Round(
      number: json['number']! as int,
      pickerId: json['picker']! as String,
      letter: json['letter'] as String?,
      deadline: _readDeadline(json['deadlineIn']),
      submittedPlayerIds: {
        for (final id in json['submitted']! as List) id as String,
      },
      answers: [
        for (final answer in json['answers']! as List)
          Answer(
            playerId: (answer as Map<String, Object?>)['player']! as String,
            category: Category.values.byName(answer['category']! as String),
            text: answer['text']! as String,
          ),
      ],
      ballot: [
        for (final item in json['ballot']! as List)
          BallotItem(
            id: (item as Map<String, Object?>)['id']! as String,
            category: Category.values.byName(item['category']! as String),
            text: item['text']! as String,
          ),
      ],
      myVotes: {
        for (final MapEntry(:key, :value)
            in (json['myVotes']! as Map<String, Object?>).entries)
          key: VoteChoice.values.byName(value! as String),
      },
      results: results == null ? null : _readResults(results),
      nextRoundReadyIds: {
        for (final id in json['nextReady']! as List) id as String,
      },
      nextRoundDeadline: _readDeadline(json['nextDeadlineIn']),
      voteDeadline: _readDeadline(json['voteIn']),
      voteTime: json['voteTime'] == null
          ? null
          : Duration(milliseconds: json['voteTime']! as int),
      votedPlayerIds: {
        for (final id in json['voted'] as List? ?? const []) id as String,
      },
    );
  }

  static Map<String, Object?> _results(RoundResults results) => {
    'scores': {
      for (final MapEntry(:key, :value) in results.scores.entries)
        key: _score(value),
    },
    'lines': {
      for (final MapEntry(:key, :value) in results.lines.entries)
        key: [
          for (final line in value)
            {
              'category': line.category.name,
              'text': line.text,
              'verdict': line.verdict?.name,
              'points': line.points,
              'byList': line.byWordList,
              'noVotes': line.noVotes,
            },
        ],
    },
  };

  static RoundResults _readResults(Map<String, Object?> json) => RoundResults(
    scores: {
      for (final MapEntry(:key, :value)
          in (json['scores']! as Map<String, Object?>).entries)
        key: _readScore(value! as Map<String, Object?>),
    },
    lines: {
      for (final MapEntry(:key, :value)
          in (json['lines']! as Map<String, Object?>).entries)
        key: [
          for (final line in value! as List)
            AnswerLine(
              category: Category.values.byName(
                (line as Map<String, Object?>)['category']! as String,
              ),
              text: line['text']! as String,
              verdict: line['verdict'] == null
                  ? null
                  : AnswerVerdict.values.byName(line['verdict']! as String),
              points: line['points']! as int,
              byWordList: line['byList'] as bool? ?? false,
              noVotes: line['noVotes'] as bool? ?? false,
            ),
        ],
    },
  );
}
