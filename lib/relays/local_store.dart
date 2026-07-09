import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../echo/runtime_mode.dart';

// ============================================================
// LOCAL STORE — persistence for the shell layer
// ============================================================
// Booleans + ints live in SharedPreferences; URLs live inside
// flutter_secure_storage so they do not surface in a plain-text
// prefs dump. Keys are terse & neutral on purpose.
//
// This class is used by the router / veils only. The native game
// keeps its own storage in `lib/services/game_storage.dart` — two
// separate stores by design.
// ============================================================

const String _tag = '[LocalStore]';

class LocalStore {
  LocalStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kMode = 'mrb_runtime_mode_v1';
  static const String _kDestination = 'mrb_dest_blob';
  static const String _kExpiresAt = 'mrb_dest_ttl';
  static const String _kInviteMuteUntil = 'mrb_invite_mute';
  static const String _kPushGranted = 'mrb_push_granted';
  static const String _kPushOsDenied = 'mrb_push_os_denied';
  static const String _kPushColdLink = 'mrb_push_cold_blob';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('$_tag warmUp() done — mode="${_prefs.getString(_kMode)}"');
  }

  // ── Runtime mode ──
  RuntimeMode readMode() {
    final RuntimeMode mode = RuntimeMode.read(_prefs.getString(_kMode));
    debugPrint('$_tag readMode() → $mode');
    return mode;
  }

  Future<void> writeMode(RuntimeMode mode) {
    debugPrint('$_tag writeMode($mode)');
    return _prefs.setString(_kMode, mode.write());
  }

  // ── Cached destination URL (secure) ──
  Future<String?> readDestination() async {
    final String? v = await _secure.read(key: _kDestination);
    debugPrint('$_tag readDestination() → ${v == null ? "null" : "(present, ${v.length} chars)"}');
    return v;
  }

  Future<void> writeDestination(String link) {
    debugPrint('$_tag writeDestination(${link.length} chars)');
    return _secure.write(key: _kDestination, value: link);
  }

  // ── Expiry ──
  int? readExpiry() => _prefs.getInt(_kExpiresAt);

  Future<void> writeExpiry(int unixSeconds) =>
      _prefs.setInt(_kExpiresAt, unixSeconds);

  bool isExpired() {
    final int? ttl = readExpiry();
    if (ttl == null) return true;
    return _nowSeconds() >= ttl;
  }

  // ── Push permission ──
  bool isPushGranted() => _prefs.getBool(_kPushGranted) ?? false;
  Future<void> setPushGranted(bool v) {
    debugPrint('$_tag setPushGranted($v)');
    return _prefs.setBool(_kPushGranted, v);
  }

  /// True once the OS dialog was denied — Android will silently ignore
  /// further permission requests, so the invite screen must not loop.
  bool isPushOsDenied() => _prefs.getBool(_kPushOsDenied) ?? false;
  Future<void> markPushOsDenied() {
    debugPrint('$_tag markPushOsDenied()');
    return _prefs.setBool(_kPushOsDenied, true);
  }

  int? readInviteMute() => _prefs.getInt(_kInviteMuteUntil);
  Future<void> writeInviteMute(int unixSeconds) =>
      _prefs.setInt(_kInviteMuteUntil, unixSeconds);

  /// Decides whether to show the push invite before the WebView.
  bool shouldInvite() {
    if (isPushGranted()) {
      debugPrint('$_tag shouldInvite() → false (push already granted)');
      return false;
    }
    if (isPushOsDenied()) {
      debugPrint('$_tag shouldInvite() → false (OS denied)');
      return false;
    }
    final int? until = readInviteMute();
    if (until == null) {
      debugPrint('$_tag shouldInvite() → true (no mute set)');
      return true;
    }
    final bool show = _nowSeconds() >= until;
    debugPrint('$_tag shouldInvite() → $show (mute until=$until, now=${_nowSeconds()})');
    return show;
  }

  // ── One-shot cold-tap push link (secure) ──
  Future<void> stashColdPush(String? link) async {
    debugPrint('$_tag stashColdPush(${link == null ? "null" : "present"})');
    if (link == null) {
      await _secure.delete(key: _kPushColdLink);
    } else {
      await _secure.write(key: _kPushColdLink, value: link);
    }
  }

  Future<String?> consumeColdPush() async {
    final String? v = await _secure.read(key: _kPushColdLink);
    debugPrint('$_tag consumeColdPush() → ${v == null ? "null" : "found, deleting"}');
    if (v != null) await _secure.delete(key: _kPushColdLink);
    return v;
  }

  /// Full reset — clears runtime mode, cached destination + expiry and
  /// any stashed push link so the next boot goes through the fresh path.
  /// Used when a OneLink open re-opens the gate.
  Future<void> resetForFreshBoot() async {
    debugPrint('$_tag resetForFreshBoot()');
    await _prefs.remove(_kMode);
    await _prefs.remove(_kExpiresAt);
    await _prefs.remove(_kInviteMuteUntil);
    await _secure.delete(key: _kDestination);
    await _secure.delete(key: _kPushColdLink);
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
