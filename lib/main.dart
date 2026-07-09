import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'orbit/orbit_app.dart';
import 'relays/attribution_relay.dart';
import 'relays/local_store.dart';
import 'relays/net_probe.dart';
import 'relays/push_relay.dart';
import 'relays/ua_stamp.dart';
import 'relays/verdict_relay.dart';
import 'theme.dart';

// ============================================================
// main.dart — Marble Descent bootstrap
// ============================================================
// Wiring order (do NOT reshuffle without reading the guide):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck   — wrapped in try/catch. The template
//      ships without google-services.json; failure must never block
//      startup — the shell will just fall back to the native game.
//   3. Orientation whitelist — all four; the game re-locks to
//      portrait inside RoutePilot._toNative().
//   4. Status bar transparent + light icons.
//   5. marbleWire.warmUp() — forges the device UA used by BOTH the
//      HTTP client and the WebView (chrome/webkit fragments come
//      from the glyph pack).
//   6. LocalStore.warmUp() — reads SharedPreferences into memory so
//      the pilot's first frame can decide the route synchronously.
//   7. Relays are constructed; PushRelay + AttributionRelay
//      actually boot inside the pilot after the UI is up.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Boot] main() — bindings ready');

  try {
    await Firebase.initializeApp();
    debugPrint('[Boot] Firebase.initializeApp OK');
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    debugPrint('[Boot] AppCheck activated (${kDebugMode ? "debug" : "playIntegrity"})');
  } catch (e) {
    debugPrint('[Boot] Firebase init failed: $e — continuing without');
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await marbleWire.warmUp();
  debugPrint('[Boot] marbleWire ready — UA warmed');

  final LocalStore store = LocalStore();
  await store.warmUp();
  debugPrint('[Boot] LocalStore ready — storedMode=${store.readMode()} '
      'override=${store.isTestShellOverride()}');

  final NetProbe netProbe = NetProbe();
  final AttributionRelay attribution = AttributionRelay();
  final VerdictRelay verdicts = VerdictRelay(store);
  final PushRelay pushRelay = PushRelay(store);
  debugPrint('[Boot] relays constructed — launching OrbitApp');

  runApp(OrbitApp(
    store: store,
    netProbe: netProbe,
    attribution: attribution,
    verdicts: verdicts,
    pushRelay: pushRelay,
  ));
}
