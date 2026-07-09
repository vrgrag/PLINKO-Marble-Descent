import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../echo/verdict_echo.dart';
import '../nexus/identity.dart';
import 'local_store.dart';
import 'ua_stamp.dart';

// ============================================================
// VERDICT RELAY — POST the merged body, read the reply
// ============================================================
// Sends the assembled body to the verdict endpoint. On an approved
// reply the destination + ttl are cached so returning launches can
// fall back to them if the network later fails. Missing endpoint or
// any error yields a rejected reply, which routes to the native game.
//
// Config contract §"Последующие запуски": on a returning launch the
// cached url is served directly while its `expires` TTL is still in the
// future (no network call). A fresh verdict POST is only sent once the
// link has expired; the cached url then remains the fallback if that
// refresh request fails.
// ============================================================

const String _tag = '[VerdictRelay]';

class VerdictRelay {
  VerdictRelay(this._store);

  final LocalStore _store;

  Future<VerdictEcho> ask(Map<String, dynamic> body) async {
    final String endpoint = MarbleIdentity.verdictEndpoint;
    debugPrint('$_tag ask() endpoint="${endpoint.isEmpty ? "EMPTY" : endpoint}"');

    if (endpoint.isEmpty) {
      debugPrint('$_tag no-endpoint — rejecting');
      return VerdictEcho.rejected('no-endpoint');
    }

    debugPrint('$_tag POST → $endpoint  bodyKeys=${body.keys.toList()}');
    if (kDebugMode) {
      debugPrint('$_tag body JSON: ${jsonEncode(body)}');
    }

    try {
      final response = await marbleWire
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('$_tag response: ${response.statusCode}  body="${response.body}"');

      if (response.statusCode != 200) {
        debugPrint('$_tag non-200 → rejected(http-${response.statusCode})');
        return VerdictEcho.rejected('http-${response.statusCode}');
      }

      final Map<String, dynamic> raw =
          jsonDecode(response.body) as Map<String, dynamic>;
      final VerdictEcho echo = VerdictEcho.fromWire(raw);
      debugPrint('$_tag echo: approved=${echo.approved}  destination=${echo.destination}  note=${echo.note}');

      if (echo.approved && echo.hasDestination) {
        debugPrint('$_tag approved — caching destination + expiry');
        await _store.writeDestination(echo.destination!);
        if (echo.expiresAt != null) {
          await _store.writeExpiry(echo.expiresAt!);
        }
      }
      return echo;
    } catch (e) {
      debugPrint('$_tag error: $e');
      return VerdictEcho.rejected(e.toString());
    }
  }

  Future<String?> cached() => _store.readDestination();
}
