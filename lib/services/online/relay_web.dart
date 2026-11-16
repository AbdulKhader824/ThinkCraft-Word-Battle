import 'relay.dart';

// The web version offers practice only. Phones use relay_io.dart.

Future<RelaySocket> openRelaySocket(Uri uri) {
  throw UnsupportedError('Online rooms need the phone app.');
}
