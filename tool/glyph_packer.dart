// ignore_for_file: avoid_print
// ============================================================
// GLYPH PACKER — encodes plaintext secrets into byte arrays
// ============================================================
// Mirrors lib/glyph/glyph_codec.dart. Run with:
//   dart run tool/glyph_packer.dart
// then paste the printed arrays into lib/glyph/glyph_pack.dart.
//
// Always use `dart run` (native 64-bit ints). Do NOT port this to
// PowerShell — it overflows at 32 bits and corrupts bytes (see
// gray_part_pitfalls.md).
//
// The seed / span here MUST match glyph_codec.dart exactly.
// ============================================================

const String seedPhrase = 'mB!7pQrN9x_marb149';
const int streamSpan = 34;

List<int> weaveStream() {
  int hash = 0;
  for (final int c in seedPhrase.codeUnits) {
    hash = (hash + c) & 0xFFFFFFFF;
    hash = (hash + ((hash << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    hash = hash ^ (hash >> 6);
  }
  hash = (hash + ((hash << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  hash = hash ^ (hash >> 11);
  hash = (hash + ((hash << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF;

  int state = hash == 0 ? 0x6D2B79F5 : hash;
  final List<int> stream = List<int>.filled(streamSpan, 0);
  for (int i = 0; i < streamSpan; i++) {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = state;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    stream[i] = ((t ^ (t >> 14)) & 0xFF);
  }
  return stream;
}

final List<int> stream = weaveStream();

List<int> weave(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ stream[i % streamSpan] ^ ((i * 31) & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, populate later)');
    print('const List<int> _$label = <int>[];\n');
    return;
  }
  final List<int> packed = weave(plain);
  print('// $label  <=  "$plain"');
  print('const List<int> _$label = <int>[${packed.join(', ')}];\n');
}

void main() {
  // ── Plaintext values (do NOT ship this file with real secrets) ──
  const String verdictEndpoint = 'https://marbledescent.com/config.php';
  const String gcdOrigin = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String chromeMajor = '149.0.7220.24';
  const String webkitTag = '537.36';

  // AppsFlyer Dev Key + Firebase project number (from google-services.json).
  const String attributionKey = 'TAL6RnmCGYEgUQGPMrTwUQ';
  const String messagingProject = '504784246070';

  print('=== Marble Descent glyph_packer ===\n');
  emit('verdictEndpoint', verdictEndpoint);
  emit('gcdOrigin', gcdOrigin);
  emit('chromeMajor', chromeMajor);
  emit('webkitTag', webkitTag);
  emit('attributionKey', attributionKey);
  emit('messagingProject', messagingProject);
  print('// Paste the six arrays above into lib/glyph/glyph_pack.dart.');
}
