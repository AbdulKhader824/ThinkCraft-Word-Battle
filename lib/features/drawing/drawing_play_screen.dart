import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_screen.dart';
import '../../core/widgets/player_avatar.dart';
import '../../models/drawing_room.dart';
import '../../models/sketch.dart';
import '../../services/drawing/drawing_providers.dart';
import '../../services/drawing/drawing_service.dart';
import '../../services/rules/drawing_rules.dart';
import '../../services/sound_service.dart';
import '../gameplay/leave_game_guard.dart';
import 'drawing_canvas.dart';

/// One turn of Guess the Drawing: the drawer picks a word and draws it,
/// everyone else watches and guesses, then the word is shown.
class DrawingPlayScreen extends ConsumerStatefulWidget {
  const DrawingPlayScreen({super.key});

  @override
  ConsumerState<DrawingPlayScreen> createState() => _DrawingPlayScreenState();
}

class _DrawingPlayScreenState extends ConsumerState<DrawingPlayScreen> {
  int _colour = 0;
  int _size = 1;
  bool _erasing = false;

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(drawingRoomProvider);
    final service = ref.watch(drawingServiceProvider);
    final myId = service.localPlayerId;
    ref.listen(drawingRoomProvider, (previous, next) {
      _playSounds(previous, next, myId);
    });
    if (room == null || myId == null) return const SizedBox.shrink();

    final isDrawer = room.drawerId == myId;
    final Widget body;
    if (room.phase == DrawingPhase.choosing) {
      body = isDrawer
          ? _ChooseWord(room: room, onChoose: service.chooseWord)
          : _WaitingForWord(room: room);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WordStrip(room: room, isDrawer: isDrawer),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Center(
              child: SketchCanvas(
                key: ValueKey('canvas-${room.turnId}'),
                sketch: service.sketch,
                changes: service.sketchChanges,
                colour: _erasing ? Sketch.eraser : _colour,
                size: _erasing ? 2 : _size,
                onOp: isDrawer && room.phase == DrawingPhase.drawing
                    ? service.draw
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (room.phase == DrawingPhase.turnResult)
            _TurnResult(room: room)
          else if (isDrawer)
            _Toolbar(
              colour: _colour,
              size: _size,
              erasing: _erasing,
              onColour: (colour) => setState(() {
                _colour = colour;
                _erasing = false;
              }),
              onSize: () => setState(() {
                _size = (_size + 1) % DrawingPalette.sizes.length;
                _erasing = false;
              }),
              onEraser: () => setState(() => _erasing = !_erasing),
              onUndo: () => service.draw(const SketchUndo()),
              onClear: () => service.draw(const SketchClear()),
            )
          else
            _GuessArea(room: room, myId: myId, service: service),
        ],
      );
    }

    return LeaveGameGuard(
      leave: service.leaveRoom,
      child: GameFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                room: room,
                myId: myId,
                onLeave: () =>
                    confirmLeaveGame(context, ref, leave: service.leaveRoom),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  void _playSounds(DrawingRoom? previous, DrawingRoom? next, String? myId) {
    if (previous == null || next == null) return;
    final newTurn = next.turnId != previous.turnId;
    if (!newTurn && next.guessedIds.length > previous.guessedIds.length) {
      final latest = next.guessedIds.last;
      playSound(ref, latest == myId ? GameSound.valid : GameSound.ready);
    } else if (next.phase != previous.phase) {
      switch (next.phase) {
        case DrawingPhase.turnResult:
          playSound(ref, GameSound.reveal);
        case DrawingPhase.choosing when next.drawerId == myId:
          playSound(ref, GameSound.select);
        case DrawingPhase.drawing:
          playSound(ref, GameSound.lock);
        default:
          break;
      }
    } else if (next.feed.length > previous.feed.length) {
      final entry = next.feed.last;
      if (entry.kind == FeedKind.close && entry.playerId == myId) {
        playSound(ref, GameSound.tick);
      }
    }
  }
}

/// Who is drawing, which round and turn, and the timer.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.room,
    required this.myId,
    required this.onLeave,
  });

  final DrawingRoom room;
  final String myId;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final drawer = room.drawer;
    final deadline = room.deadline;
    final isDrawer = room.drawerId == myId;
    final who = drawer == null
        ? ''
        : isDrawer
        ? 'Your turn to draw!'
        : '${drawer.name} is drawing';

    return Row(
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(
            tooltip: 'Leave game',
            iconSize: 26,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget,
            ),
            color: AppColors.navy,
            onPressed: onLeave,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (drawer != null) ...[
          PlayerAvatar(index: drawer.avatarIndex, size: 44),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label,
              ),
              Text(
                'Round ${room.round} of ${room.settings.rounds} · '
                'Turn ${room.turnInRound} of ${room.turnsInRound}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall,
              ),
            ],
          ),
        ),
        if (deadline != null && room.phase != DrawingPhase.turnResult)
          CountdownRing(
            key: ValueKey('ring-${room.turnId}-${room.phase.name}'),
            deadline: deadline,
            total: room.stageTime,
            size: 56,
          ),
      ],
    );
  }
}

/// The drawer's three words to pick from.
class _ChooseWord extends StatelessWidget {
  const _ChooseWord({required this.room, required this.onChoose});

  final DrawingRoom room;
  final ValueChanged<int> onChoose;

  static const _colours = [AppColors.mint, AppColors.sky, AppColors.peach];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pick a word to draw',
            textAlign: TextAlign.center,
            style: AppText.heading,
          ),
          Text(
            "Only you can see these. Don't say it out loud!",
            textAlign: TextAlign.center,
            style: AppText.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (index, word) in room.choices.indexed) ...[
            _WordChoice(
              key: ValueKey('word-choice-$index'),
              word: word,
              color: _colours[index % _colours.length],
              onTap: () {
                playSoundFrom(context, GameSound.select);
                onChoose(index);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _WordChoice extends StatelessWidget {
  const _WordChoice({
    super.key,
    required this.word,
    required this.color,
    required this.onTap,
  });

  final String word;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return Semantics(
      button: true,
      label: 'Draw $word',
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.navy, width: 3),
            ),
            child: Row(
              children: [
                const Icon(Icons.brush_rounded, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    word.toUpperCase(),
                    style: AppText.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${word.replaceAll(' ', '').length}',
                  style: AppText.label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What everyone but the drawer sees while a word is picked.
class _WaitingForWord extends StatelessWidget {
  const _WaitingForWord({required this.room});

  final DrawingRoom room;

  @override
  Widget build(BuildContext context) {
    final drawer = room.drawer;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (drawer != null)
              PlayerAvatar(index: drawer.avatarIndex, size: 112),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${drawer?.name ?? 'Someone'} is choosing a word...',
              textAlign: TextAlign.center,
              style: AppText.heading,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Get ready to guess fast!',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }
}

/// The word for the drawer, or its blanks and hints for guessers.
class _WordStrip extends StatelessWidget {
  const _WordStrip({required this.room, required this.isDrawer});

  final DrawingRoom room;
  final bool isDrawer;

  /// "r__k" as "R _ _ K", with a wider gap between words.
  static String spaced(String text) => text
      .toUpperCase()
      .split(' ')
      .map((word) => word.split('').join(' '))
      .join('     ');

  @override
  Widget build(BuildContext context) {
    final word = room.word;
    final mask = room.wordMask;
    final String caption;
    final String shown;
    if (word != null) {
      shown = word.toUpperCase();
      caption = room.phase == DrawingPhase.turnResult
          ? 'The word was'
          : isDrawer
          ? 'Draw this!'
          : 'You got it!';
    } else {
      shown = spaced(mask ?? '');
      final letters = (mask ?? '').replaceAll(' ', '').length;
      caption = 'Guess the word · $letters letters';
    }

    return GameCard(
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          Text(caption, style: AppText.bodySmall.copyWith(color: Colors.white)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              shown,
              key: const ValueKey('word-strip'),
              maxLines: 1,
              style: AppText.title.copyWith(
                color: AppColors.sunshine,
                letterSpacing: word == null ? 1 : 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawer's tools: colour, pen size, eraser, undo and clear.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.colour,
    required this.size,
    required this.erasing,
    required this.onColour,
    required this.onSize,
    required this.onEraser,
    required this.onUndo,
    required this.onClear,
  });

  final int colour;
  final int size;
  final bool erasing;
  final ValueChanged<int> onColour;
  final VoidCallback onSize;
  final VoidCallback onEraser;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  Future<void> _pickColour(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick a colour', style: AppText.heading),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final (index, swatch) in DrawingPalette.colours.indexed)
                    Semantics(
                      button: true,
                      selected: index == colour,
                      label: DrawingPalette.colourNames[index],
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey('colour-$index'),
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(index),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: index == colour
                                  ? AppColors.navy
                                  : Colors.white,
                              width: index == colour ? 5 : 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onColour(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dot = 8.0 + size * 8;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolButton(
          key: const ValueKey('tool-colour'),
          label: 'Colour: ${DrawingPalette.colourNames[colour]}',
          selected: !erasing,
          onTap: () => _pickColour(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DrawingPalette.colours[colour],
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.navy, width: 2),
            ),
          ),
        ),
        _ToolButton(
          key: const ValueKey('tool-size'),
          label: 'Pen size: ${DrawingPalette.sizeNames[size]}',
          onTap: onSize,
          child: Container(
            width: dot,
            height: dot,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
          ),
        ),
        _ToolButton(
          key: const ValueKey('tool-eraser'),
          label: erasing ? 'Eraser on' : 'Eraser',
          selected: erasing,
          onTap: onEraser,
          child: const Icon(Icons.auto_fix_normal_rounded, size: 28),
        ),
        _ToolButton(
          key: const ValueKey('tool-undo'),
          label: 'Undo',
          onTap: onUndo,
          child: const Icon(Icons.undo_rounded, size: 28),
        ),
        _ToolButton(
          key: const ValueKey('tool-clear'),
          label: 'Clear',
          onTap: onClear,
          child: const Icon(Icons.delete_outline_rounded, size: 28),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.small);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.sunshine : AppColors.surface,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              playSoundFrom(context, GameSound.tap);
              onTap();
            },
            child: Container(
              width: AppSizes.minTapTarget,
              height: AppSizes.minTapTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: AppColors.navy, width: 2),
              ),
              child: IconTheme(
                data: const IconThemeData(color: AppColors.navy),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The guess feed and the box to type a guess in.
class _GuessArea extends StatefulWidget {
  const _GuessArea({
    required this.room,
    required this.myId,
    required this.service,
  });

  final DrawingRoom room;
  final String myId;
  final DrawingService service;

  @override
  State<_GuessArea> createState() => _GuessAreaState();
}

class _GuessAreaState extends State<_GuessArea> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = DrawingRules.cleanGuess(_controller.text);
    if (text.isEmpty) return;
    widget.service.guess(text);
    _controller.clear();
    // Stay in the box, ready for the next guess.
    _focus.requestFocus();
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.small),
    borderSide: BorderSide(color: color, width: 3),
  );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final guessed = room.guessedIds.contains(widget.myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Feed(room: room, myId: widget.myId),
        const SizedBox(height: AppSpacing.xs),
        if (guessed)
          GameCard(
            color: AppColors.mint,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: AppColors.navy),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'You got it! Watch the others guess.',
                    style: AppText.label,
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('guess-field'),
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      DrawingRules.maxGuessLength,
                    ),
                  ],
                  style: AppText.input,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type your guess',
                    hintStyle: AppText.input.copyWith(
                      color: AppColors.navySoft,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                    enabledBorder: _border(AppColors.outline),
                    focusedBorder: _border(AppColors.mintDeep),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Material(
                color: AppColors.mint,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.navy, width: 2),
                ),
                child: IconButton(
                  key: const ValueKey('guess-send'),
                  tooltip: 'Send guess',
                  iconSize: 28,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTapTarget,
                    minHeight: AppSizes.minTapTarget,
                  ),
                  color: AppColors.navy,
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The latest guesses, newest at the bottom.
class _Feed extends StatelessWidget {
  const _Feed({required this.room, required this.myId});

  final DrawingRoom room;
  final String myId;

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final entries = room.feed.length > _shown
        ? room.feed.sublist(room.feed.length - _shown)
        : room.feed;

    return GameCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: SizedBox(
        height: 72,
        child: entries.isEmpty
            ? Center(
                child: Text('Guesses show up here.', style: AppText.bodySmall),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in entries)
                    _FeedLine(room: room, entry: entry, myId: myId),
                ],
              ),
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({
    required this.room,
    required this.entry,
    required this.myId,
  });

  final DrawingRoom room;
  final FeedEntry entry;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final player = room.playerOrNull(entry.playerId);
    final name = entry.playerId == myId ? 'You' : player?.name ?? 'Someone';
    final (String text, Color colour) = switch (entry.kind) {
      FeedKind.correct => ('🎉 $name got it!', AppColors.valid),
      FeedKind.close => ('"${entry.text}" is so close!', AppColors.coralDeep),
      FeedKind.guess => ('$name: ${entry.text}', AppColors.navy),
    };
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.bodySmall.copyWith(color: colour),
    );
  }
}

/// Shown when the turn ends: why, and who won points.
class _TurnResult extends StatelessWidget {
  const _TurnResult({required this.room});

  final DrawingRoom room;

  String get _headline {
    final drawer = room.drawer?.name ?? 'The drawer';
    return switch (room.turnEnd) {
      TurnEnd.allGuessed => 'Everyone got it!',
      TurnEnd.timeUp =>
        room.guessedIds.isEmpty ? "Time's up! Nobody got it." : "Time's up!",
      TurnEnd.drawerLeft => '$drawer left, so nobody scores this turn.',
      null => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final winners = [
      for (final player in room.players)
        if ((room.turnPoints[player.id] ?? 0) > 0) player,
    ]..sort((a, b) => room.turnPoints[b.id]!.compareTo(room.turnPoints[a.id]!));

    return GameCard(
      color: AppColors.sunshine,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_headline, textAlign: TextAlign.center, style: AppText.label),
          if (winners.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: [
                for (final player in winners)
                  _PointsChip(
                    avatar: player.avatarIndex,
                    name: player.name,
                    points: room.turnPoints[player.id]!,
                    isDrawer: player.id == room.drawerId,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  const _PointsChip({
    required this.avatar,
    required this.name,
    required this.points,
    required this.isDrawer,
  });

  final int avatar;
  final String name;
  final int points;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name, plus $points points',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxs,
          AppSpacing.xxs,
          AppSpacing.sm,
          AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.navy, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(index: avatar, size: 28),
            const SizedBox(width: AppSpacing.xxs),
            if (isDrawer) ...[
              const Icon(Icons.brush_rounded, size: 16, color: AppColors.navy),
              const SizedBox(width: 2),
            ],
            Text('+$points', style: AppText.label),
          ],
        ),
      ),
    );
  }
}
