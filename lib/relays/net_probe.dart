import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// NET PROBE — connectivity + reachability helper
// ============================================================
// [isConnected] does a real DNS lookup rather than trusting the
// adapter state alone. Captive portals / limited networks are
// then correctly treated as offline.
//
// See gray_part_pitfalls.md §3 for the reasoning behind the
// 7-second DNS timeout and the VPN-included active set.
// ============================================================

const String _tag = '[NetProbe]';

class NetProbe {
  NetProbe({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    // VPN qualifies as a real interface. Filtering it out leads to
    // false-negative offline banners while the VPN tunnel is up.
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  Future<bool> isConnected() async {
    final List<ConnectivityResult> adapters =
        await _connectivity.checkConnectivity();
    debugPrint('$_tag adapters=$adapters');
    if (!adapters.any(_liveAdapters.contains)) {
      debugPrint('$_tag → offline (no live adapter)');
      return false;
    }
    try {
      final List<InternetAddress> hit = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 7));
      final bool ok = hit.isNotEmpty && hit.first.rawAddress.isNotEmpty;
      debugPrint('$_tag DNS lookup → ${ok ? "OK (${hit.first.address})" : "empty"}');
      return ok;
    } catch (e) {
      debugPrint('$_tag DNS lookup failed: $e → offline');
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get pulses =>
      _connectivity.onConnectivityChanged;
}
