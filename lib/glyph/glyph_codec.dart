import 'dart:typed_data';

// ============================================================
// GLYPH CODEC — keystream string obfuscator (Marble Descent build)
// ============================================================
// Sensitive strings — config endpoint, AppsFlyer dev key, Firebase
// project number, User-Agent version fragments — never appear as
// plaintext in the binary. They live in `glyph_pack.dart` as byte
// arrays produced by `tool/glyph_packer.dart` and are decoded here
// at runtime with the routine below.
//
// Scheme (unique to this project — do NOT reuse in a sibling app):
//   1. `_seedPhrase` feeds a MurmurOAAT 32-bit hash to seed a
//      mulberry32 generator.
//   2. Mulberry32 yields `_streamSpan` bytes of keystream.
//   3. Each output byte = input ^ stream[i % span] ^ ((i * 31) & 0xFF).
//      The multiplicative positional term is different from every
//      other gray-flow project in the account, so identical raw
//      values produce a wholly different encoding.
//
// The transform is symmetric — `tool/glyph_packer.dart` encodes with
// the same seed / span / permutation.
//
// [FINGERPRINT] Mandatory per-project change:
//   • pick a fresh, opaque `_seedPhrase` (do not reuse this one)
//   • pick a new `_streamSpan` (16 – 48, different from siblings)
//   • re-run tool/glyph_packer.dart and re-paste glyph_pack.dart
// ============================================================

const String _seedPhrase = 'mB!7pQrN9x_marb149';
const int _streamSpan = 34;

Uint8List _weaveStream() {
  // MurmurOAAT 32-bit over the seed.
  int hash = 0;
  for (final int c in _seedPhrase.codeUnits) {
    hash = (hash + c) & 0xFFFFFFFF;
    hash = (hash + ((hash << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    hash = hash ^ (hash >> 6);
  }
  hash = (hash + ((hash << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  hash = hash ^ (hash >> 11);
  hash = (hash + ((hash << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF;

  int state = hash == 0 ? 0x6D2B79F5 : hash;
  final Uint8List stream = Uint8List(_streamSpan);
  for (int i = 0; i < _streamSpan; i++) {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = state;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    stream[i] = ((t ^ (t >> 14)) & 0xFF);
  }
  return stream;
}

final Uint8List _stream = _weaveStream();

/// Decodes a packed byte list back into a string. Returns an empty
/// string for an empty input — the safe path before real secrets are
/// packed via `tool/glyph_packer.dart`.
String unweave(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _stream[i % _streamSpan] ^ ((i * 31) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
