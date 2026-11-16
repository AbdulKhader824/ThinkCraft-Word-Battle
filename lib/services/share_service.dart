import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet (WhatsApp, messages and so on) with some
/// text. Tests replace it, so they don't need the phone's share sheet.
typedef ShareText = Future<void> Function(String text);

final shareTextProvider = Provider<ShareText>((ref) => _shareWithApps);

Future<void> _shareWithApps(String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } on Object {
    // Nothing to share with, such as on some web browsers.
  }
}

/// The message a player sends friends to bring them into an online room.
String onlineInvite({required String game, required String code}) =>
    'Play $game with me on PlayPals! Open $game, tap Join Room, pick '
    'Friends online and type the code $code';
