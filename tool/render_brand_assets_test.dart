// Renders the logo SVG into the PNG files that the icon and splash tools
// need. Run it again whenever the logo changes:
//
//   flutter test tool/render_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// It lives in tool/, so normal `flutter test` runs never execute it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _logo = 'assets/images/logo.svg';
const _out = 'assets/branding';
const _navy = Color(0xFF1B2A5B);

Future<void> _render({
  required String file,
  required int size,
  required double logoWidth,
  Color? background,
}) async {
  final svg = File(_logo).readAsStringSync();
  final logo = await vg.loadPicture(SvgStringLoader(svg), null);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = background,
    );
  }

  final scale = logoWidth / logo.size.width;
  final logoHeight = logo.size.height * scale;
  canvas
    ..translate((size - logoWidth) / 2, (size - logoHeight) / 2)
    ..scale(scale)
    ..drawPicture(logo.picture);

  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_out/$file')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render brand PNGs', () async {
    // Older launchers: the whole square is shown, on navy.
    await _render(
      file: 'icon.png',
      size: 1024,
      logoWidth: 760,
      background: _navy,
    );
    // Adaptive icons: the launcher crops to a shape and may show only the
    // central 66 of 108 units. flutter_launcher_icons then adds a 16% inset,
    // so 700 becomes about 476, whose corners stay inside that safe circle.
    await _render(file: 'icon_foreground.png', size: 1024, logoWidth: 700);
    // Splash before Android 12: drawn at a quarter size, so 180dp wide.
    await _render(file: 'splash.png', size: 768, logoWidth: 720);
    // Android 12+ splash: shown inside a circle two-thirds of the image.
    await _render(file: 'splash_android12.png', size: 1152, logoWidth: 560);
  });
}
