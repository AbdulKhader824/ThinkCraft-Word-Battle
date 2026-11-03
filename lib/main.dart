import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final profiles = await PrefsProfileStore.open();

  runApp(
    ProviderScope(
      overrides: [profileStoreProvider.overrideWithValue(profiles)],
      child: const ThinkCraftApp(),
    ),
  );
}
