import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file.
///
/// Tests normally draw text with a placeholder font whose letters are wide
/// squares, which makes layout checks fail on text that fits on a real
/// phone. Loading the app's real fonts makes the size tests honest.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (family, asset) in const [
    ('Fredoka', 'assets/fonts/Fredoka.ttf'),
    ('Nunito', 'assets/fonts/Nunito.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }

  await testMain();
}
