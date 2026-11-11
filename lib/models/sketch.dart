/// A drawing, kept as the strokes that made it, so it can be sent between
/// phones a few points at a time and redrawn at any screen size.
///
/// Points are whole numbers from 0 to [Sketch.scale] across and down the
/// canvas. Every phone shows the canvas at the same shape, so a point lands
/// in the same place on a small phone and a big one.
library;

/// One line drawn without lifting the finger.
class SketchStroke {
  SketchStroke({required this.colour, required this.size, List<int>? points})
    : points = points ?? [];

  /// An index into the drawing palette. The eraser is [Sketch.eraser].
  final int colour;

  /// An index into the pen sizes.
  final int size;

  /// x, y, x, y, ... from 0 to [Sketch.scale].
  final List<int> points;

  Map<String, Object?> toJson() => {'c': colour, 's': size, 'p': points};

  static SketchStroke fromJson(Map<String, Object?> json) {
    return SketchStroke(
      colour: json['c']! as int,
      size: json['s']! as int,
      points: [for (final value in json['p']! as List<Object?>) value! as int],
    );
  }
}

/// A change to a drawing. The drawer's phone makes these, and every other
/// phone applies the same ones in the same order.
sealed class SketchOp {
  const SketchOp();

  Map<String, Object?> toJson();

  static SketchOp fromJson(Map<String, Object?> json) {
    return switch (json['o']) {
      'start' => StrokeStart(
        colour: json['c']! as int,
        size: json['s']! as int,
        points: _points(json['p']),
      ),
      'add' => StrokeAdd(_points(json['p'])),
      'undo' => const SketchUndo(),
      'clear' => const SketchClear(),
      final other => throw FormatException('Unknown sketch change: $other'),
    };
  }

  static List<int> _points(Object? json) {
    return [for (final value in json! as List<Object?>) value! as int];
  }
}

/// A new stroke begins, with its first points.
class StrokeStart extends SketchOp {
  const StrokeStart({
    required this.colour,
    required this.size,
    required this.points,
  });

  final int colour;
  final int size;
  final List<int> points;

  @override
  Map<String, Object?> toJson() => {
    'o': 'start',
    'c': colour,
    's': size,
    'p': points,
  };
}

/// More points for the stroke being drawn.
class StrokeAdd extends SketchOp {
  const StrokeAdd(this.points);

  final List<int> points;

  @override
  Map<String, Object?> toJson() => {'o': 'add', 'p': points};
}

/// Takes away the last stroke.
class SketchUndo extends SketchOp {
  const SketchUndo();

  @override
  Map<String, Object?> toJson() => {'o': 'undo'};
}

/// Wipes the whole drawing.
class SketchClear extends SketchOp {
  const SketchClear();

  @override
  Map<String, Object?> toJson() => {'o': 'clear'};
}

/// The drawing itself. It changes in place as points arrive, which is much
/// cheaper than copying every stroke many times a second; [version] goes up
/// with each change, so a screen can tell it needs repainting.
class Sketch {
  /// Points run from 0 to this, across and down.
  static const scale = 1000;

  /// The colour index that means rubbing out.
  static const eraser = -1;

  /// Most strokes kept, and most points in one stroke, so one drawing
  /// can't grow without end.
  static const maxStrokes = 400;
  static const maxPointsPerStroke = 4000;

  final List<SketchStroke> strokes = [];

  int get version => _version;
  int _version = 0;

  /// Goes up whenever finished strokes change or go, rather than only the
  /// last stroke growing, so a screen knows when its saved picture of the
  /// finished strokes is out of date.
  int get generation => _generation;
  int _generation = 0;

  bool get isEmpty => strokes.isEmpty;

  void apply(SketchOp op) {
    switch (op) {
      case StrokeStart(:final colour, :final size, :final points):
        if (strokes.length >= maxStrokes) return;
        strokes.add(
          SketchStroke(colour: colour, size: size, points: [...points]),
        );
      case StrokeAdd(:final points):
        if (strokes.isEmpty) return;
        final stroke = strokes.last.points;
        if (stroke.length + points.length > maxPointsPerStroke * 2) return;
        stroke.addAll(points);
      case SketchUndo():
        if (strokes.isEmpty) return;
        strokes.removeLast();
        _generation++;
      case SketchClear():
        if (strokes.isEmpty) return;
        strokes.clear();
        _generation++;
    }
    _version++;
  }

  /// Replaces the whole drawing, such as for a player who reconnects.
  void replaceWith(List<SketchStroke> others) {
    strokes
      ..clear()
      ..addAll(others);
    _version++;
    _generation++;
  }

  void clear() {
    strokes.clear();
    _version++;
    _generation++;
  }

  List<Map<String, Object?>> toJson() => [
    for (final stroke in strokes) stroke.toJson(),
  ];

  static List<SketchStroke> strokesFromJson(Object? json) {
    return [
      for (final stroke in json! as List<Object?>)
        SketchStroke.fromJson(stroke! as Map<String, Object?>),
    ];
  }
}
