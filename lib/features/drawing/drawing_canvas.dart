import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/sketch.dart';

/// The colours and pen sizes a drawer can use. Every phone shares these,
/// because strokes travel as an index into them.
abstract final class DrawingPalette {
  static const colours = [
    AppColors.navy,
    AppColors.invalid,
    AppColors.peach,
    AppColors.sunshine,
    AppColors.valid,
    AppColors.skyDeep,
    AppColors.lavenderDeep,
    AppColors.bronze,
  ];

  static const colourNames = [
    'Navy',
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Blue',
    'Purple',
    'Brown',
  ];

  /// Pen widths, as a share of the canvas width, so a line is just as
  /// thick on every phone.
  static const sizes = [0.012, 0.028, 0.06];
  static const sizeNames = ['Thin', 'Medium', 'Thick'];

  /// The paper. The eraser paints with it.
  static const paper = Colors.white;

  static Color colourOf(int index) {
    if (index == Sketch.eraser) return paper;
    return colours[index.clamp(0, colours.length - 1)];
  }

  static double widthOf(int size, double canvasWidth) {
    return sizes[size.clamp(0, sizes.length - 1)] * canvasWidth;
  }
}

/// The square drawing paper. The drawer draws on it with a finger; everyone
/// else watches [sketch] fill in as strokes arrive.
///
/// Finished strokes are saved as one picture, so only the stroke being
/// drawn is redrawn as the finger moves.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({
    super.key,
    required this.sketch,
    required this.changes,
    this.colour = 0,
    this.size = 1,
    this.onOp,
  });

  final Sketch sketch;

  /// Fires whenever [sketch] changes.
  final Stream<void> changes;

  /// The pen, while drawing. Ignored when [onOp] is null.
  final int colour;
  final int size;

  /// Receives each change the finger makes. Null for watchers, who can't
  /// draw.
  final ValueChanged<SketchOp>? onOp;

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> {
  final _repaint = ValueNotifier<int>(0);
  StreamSubscription<void>? _subscription;
  late final _painter = _SketchPainter(widget.sketch, _repaint);

  /// The last point sent, so tiny moves aren't sent at all.
  int _lastX = -1;
  int _lastY = -1;

  /// Points closer than this to the last one are skipped.
  static const _minStep = 4;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(SketchCanvas old) {
    super.didUpdateWidget(old);
    if (old.changes != widget.changes) _listen();
    if (old.sketch != widget.sketch) {
      _painter.sketch = widget.sketch;
      _repaint.value++;
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.changes.listen((_) => _repaint.value++);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _painter.dispose();
    _repaint.dispose();
    super.dispose();
  }

  (int, int) _toPoint(Offset position, Size size) {
    int scale(double value, double length) =>
        (value / length * Sketch.scale).round().clamp(0, Sketch.scale);
    return (scale(position.dx, size.width), scale(position.dy, size.height));
  }

  void _start(Offset position, Size size) {
    final (x, y) = _toPoint(position, size);
    _lastX = x;
    _lastY = y;
    widget.onOp!(
      StrokeStart(colour: widget.colour, size: widget.size, points: [x, y]),
    );
  }

  void _move(Offset position, Size size) {
    final (x, y) = _toPoint(position, size);
    if ((x - _lastX).abs() < _minStep && (y - _lastY).abs() < _minStep) {
      return;
    }
    _lastX = x;
    _lastY = y;
    widget.onOp!(StrokeAdd([x, y]));
  }

  @override
  Widget build(BuildContext context) {
    final canDraw = widget.onOp != null;

    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DrawingPalette.paper,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.navy, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small - 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final paper = RepaintBoundary(
                child: CustomPaint(size: size, painter: _painter),
              );
              if (!canDraw) {
                return Semantics(
                  label: 'The drawing',
                  image: true,
                  child: paper,
                );
              }
              return Semantics(
                label: 'Drawing paper. Draw with your finger.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => _start(details.localPosition, size),
                  onPanUpdate: (details) => _move(details.localPosition, size),
                  child: paper,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.sketch, Listenable repaint) : super(repaint: repaint);

  Sketch sketch;

  /// The finished strokes, drawn once.
  ui.Picture? _saved;
  (int, int, Size)? _savedFor;

  void dispose() {
    _saved?.dispose();
    _saved = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokes = sketch.strokes;
    if (strokes.isEmpty) return;
    final finished = strokes.length - 1;
    final key = (sketch.generation, finished, size);
    if (_savedFor != key) {
      _saved?.dispose();
      final recorder = ui.PictureRecorder();
      final saving = Canvas(recorder);
      for (var index = 0; index < finished; index++) {
        _paintStroke(saving, strokes[index], size);
      }
      _saved = recorder.endRecording();
      _savedFor = key;
    }
    canvas.drawPicture(_saved!);
    _paintStroke(canvas, strokes.last, size);
  }

  void _paintStroke(Canvas canvas, SketchStroke stroke, Size size) {
    final points = stroke.points;
    if (points.length < 2) return;
    final width = DrawingPalette.widthOf(stroke.size, size.width);
    final paint = Paint()
      ..color = DrawingPalette.colourOf(stroke.colour)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    Offset at(int index) => Offset(
      points[index] / Sketch.scale * size.width,
      points[index + 1] / Sketch.scale * size.height,
    );

    if (points.length == 2) {
      // A tap leaves a dot.
      canvas.drawCircle(at(0), width / 2, paint..style = PaintingStyle.fill);
      return;
    }

    // Smooth curves through the midpoints, rather than sharp corners.
    final path = Path();
    var previous = at(0);
    path.moveTo(previous.dx, previous.dy);
    for (var index = 2; index < points.length - 1; index += 2) {
      final current = at(index);
      final middle = (previous + current) / 2;
      path.quadraticBezierTo(previous.dx, previous.dy, middle.dx, middle.dy);
      previous = current;
    }
    path.lineTo(previous.dx, previous.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SketchPainter old) => true;
}
