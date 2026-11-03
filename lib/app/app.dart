import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class ThinkCraftApp extends ConsumerWidget {
  const ThinkCraftApp({super.key});

  /// Large system text is supported up to this size. Beyond it, letter
  /// tiles and game cards would no longer fit on a phone.
  static const maxTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: child!,
      ),
    );
  }
}
