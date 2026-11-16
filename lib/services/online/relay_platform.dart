// Picks the real relay connection on phones, and a stand-in on the web.
export 'relay_web.dart' if (dart.library.io) 'relay_io.dart';
