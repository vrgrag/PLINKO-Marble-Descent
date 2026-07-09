/// Parsed response from the verdict (config) endpoint.
///
/// Wire format from the backend is `{ ok, url, expires, message }`.
/// The Dart-side field names are renamed for style but the JSON
/// keys are still parsed verbatim — do not tamper with the backend
/// contract.
class VerdictEcho {
  const VerdictEcho({
    required this.approved,
    this.destination,
    this.note,
    this.expiresAt,
  });

  /// Backend `ok`.
  final bool approved;

  /// Backend `url`.
  final String? destination;

  /// Backend `message`.
  final String? note;

  /// Backend `expires` (unix seconds).
  final int? expiresAt;

  bool get hasDestination =>
      destination != null && destination!.trim().isNotEmpty;

  factory VerdictEcho.fromWire(Map<String, dynamic> raw) {
    return VerdictEcho(
      approved: raw['ok'] as bool? ?? false,
      destination: raw['url'] as String?,
      note: raw['message'] as String?,
      expiresAt: raw['expires'] as int?,
    );
  }

  factory VerdictEcho.rejected(String reason) =>
      VerdictEcho(approved: false, note: reason);
}
