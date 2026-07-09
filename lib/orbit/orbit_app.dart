import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nexus/identity.dart';
import '../relays/attribution_relay.dart';
import '../relays/local_store.dart';
import '../relays/net_probe.dart';
import '../relays/push_relay.dart';
import '../relays/verdict_relay.dart';
import '../theme.dart';
import 'route_pilot.dart';

/// Root widget for Marble Descent. Owns the long-lived relay instances
/// and hands them to the route pilot.
///
/// Also owns a `navigatorKey` so the native side can push a fresh
/// [RoutePilot] onto the stack when a **warm** OneLink tap arrives —
/// i.e. the Activity was already alive (e.g. showing the native game)
/// when the user tapped the OneLink URL. In that case
/// [MainActivity.onNewIntent] fires `onDeepLinkArrived` over the
/// `marbdesc/launch_intent` channel; we listen here and rebuild the
/// router, which will then see the URI via `consumeLaunchUri`.
class OrbitApp extends StatefulWidget {
  const OrbitApp({
    super.key,
    required this.store,
    required this.netProbe,
    required this.attribution,
    required this.verdicts,
    required this.pushRelay,
  });

  final LocalStore store;
  final NetProbe netProbe;
  final AttributionRelay attribution;
  final VerdictRelay verdicts;
  final PushRelay pushRelay;

  @override
  State<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends State<OrbitApp> {
  static const MethodChannel _launchChannel =
      MethodChannel('marbdesc/launch_intent');

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _launchChannel.setMethodCallHandler(_onNativeCall);
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method != 'onDeepLinkArrived') return null;
    final Object? arg = call.arguments;
    final String uri = arg is String ? arg : arg?.toString() ?? '';
    debugPrint('[OrbitApp] warm deep-link received: "$uri" — rebooting pilot');

    // The URI itself is already stashed on the native side; the fresh
    // RoutePilot will pull it via `consumeLaunchUri` in its `_drive()`
    // pass. Wiping the runtime mode here guarantees the pilot enters
    // the fresh-boot branch regardless of what the last session
    // committed to disk.
    await widget.store.resetForFreshBoot();

    final NavigatorState? nav = _navKey.currentState;
    if (nav == null) {
      debugPrint('[OrbitApp] navigator not ready — skipping reboot');
      return null;
    }
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RoutePilot(
          store: widget.store,
          netProbe: widget.netProbe,
          attribution: AttributionRelay(),
          verdicts: widget.verdicts,
          pushRelay: widget.pushRelay,
        ),
      ),
      (_) => false,
    );
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MarbleIdentity.publicName,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.deepBlack,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neonPurple,
          brightness: Brightness.dark,
          surface: AppColors.deepBlack,
        ),
        textTheme: const TextTheme(
          bodyMedium: AppTextStyles.body,
          bodyLarge: AppTextStyles.body,
          titleLarge: AppTextStyles.heading,
          titleMedium: AppTextStyles.heading,
        ),
      ),
      home: RoutePilot(
        store: widget.store,
        netProbe: widget.netProbe,
        attribution: widget.attribution,
        verdicts: widget.verdicts,
        pushRelay: widget.pushRelay,
      ),
    );
  }
}
