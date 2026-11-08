// Picks the real local-network code on phones, and a stand-in on the web,
// where browsers can't open these connections.
export 'nearby_web.dart' if (dart.library.io) 'nearby_io.dart';
