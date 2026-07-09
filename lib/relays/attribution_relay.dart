import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../glyph/glyph_pack.dart';
import '../nexus/identity.dart';
import 'ua_stamp.dart';

// ============================================================
// ATTRIBUTION RELAY — AppsFlyer install + deep-link harvest
// ============================================================
// Collects the install conversion payload, deep-link event and
// app-open attribution, folds them into the verdict request body.
//
// Organic false-positive guard: AppsFlyer sometimes reports
// af_status == "Organic" on the first callback for a genuinely
// paid install. When that happens we wait 5 s and re-query the
// GCD endpoint to obtain the real attribution. See
// android_gray_guide.md §"AppsFlyer Organic False-Positive Fix".
//
// When no dev key is packed yet, the relay short-circuits: the
// install-data future completes immediately with an empty map so
// the router does not stall for 30 s before falling through.
// ============================================================

const String _tag = '[AttribRelay]';

class AttributionRelay {
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _kindled = false;

  /// Initialises the SDK and wires callbacks. Safe to call more than once.
  Future<void> kindle() async {
    if (_kindled) return;
    _kindled = true;

    final String devKey = MarbleIdentity.attributionKey;
    debugPrint('$_tag kindle() — devKey ${devKey.isEmpty ? "EMPTY (SDK will skip)" : "present (${devKey.length} chars)"}');

    if (devKey.isEmpty) {
      debugPrint('$_tag No dev key packed — short-circuiting, installReady with {}');
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
      return;
    }

    debugPrint('$_tag AppsFlyerOptions: appId="${MarbleIdentity.appleNumericId}", '
        'bundle="${MarbleIdentity.packageBundle}", '
        'oneLinkId="${MarbleIdentity.oneLinkTemplateId}"');
    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: MarbleIdentity.appleNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
      // OneLink template id (from https://<subdomain>.onelink.me/<ID>).
      // REQUIRED for deferred deep linking to work — without it the
      // SDK can't associate a deferred install with the OneLink click.
      appInviteOneLink: MarbleIdentity.oneLinkTemplateId,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      debugPrint('$_tag onInstallConversionData raw: $res');
      final Map<String, dynamic> payload = _flatten(res);
      debugPrint('$_tag onInstallConversionData flattened: $payload');

      final String? status = payload['af_status']?.toString();
      debugPrint('$_tag af_status = "$status"');

      if (status == 'Organic') {
        debugPrint('$_tag Organic detected — waiting ${MarbleIdentity.organicResampleDelay}s then GCD resample');
        await Future<void>.delayed(
          Duration(seconds: MarbleIdentity.organicResampleDelay),
        );
        final Map<String, dynamic>? refreshed = await _resampleGcd();
        debugPrint('$_tag GCD resample result: $refreshed');
        _installData = refreshed ?? payload;
      } else {
        _installData = payload;
      }
      debugPrint('$_tag installData resolved: $_installData');
      _resolveInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      debugPrint('$_tag onAppOpenAttribution raw: $res');
      _appOpenData = _flatten(res);
      debugPrint('$_tag appOpenData: $_appOpenData');
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      debugPrint('$_tag onDeepLinking clickEvent: $click');
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
      }
      _resolveDeepLink();
    });

    try {
      debugPrint('$_tag initSdk() starting…');
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      debugPrint('$_tag initSdk() done');
    } catch (e) {
      debugPrint('$_tag initSdk() threw: $e — resolving with {}');
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
    }
  }

  Future<Map<String, dynamic>> awaitInstall({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged verdict request body.
  ///
  /// The AppsFlyer conversion payload is forwarded VERBATIM — no field
  /// is renamed / dropped / added except for the seven device-side
  /// fields defined below. Do NOT filter the attribution data — the
  /// backend needs the full payload to route correctly.
  ///
  /// When [injectTestAttribution] is true (QA override), a synthetic
  /// Non-organic payload is added only if the SDK never delivered one.
  /// Real attribution always takes precedence — production installs
  /// via OneLink are unaffected.
  Future<Map<String, dynamic>> composeVerdictBody({
    required String locale,
    String? pushToken,
    bool injectTestAttribution = false,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    debugPrint('$_tag composeVerdictBody: installData=$_installData  deepLink=$_deepLinkData  appOpen=$_appOpenData');

    if (_installData != null) body.addAll(_installData!);
    _deepLinkData?.forEach(
        (String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenData?.forEach(
        (String k, dynamic v) => body.putIfAbsent(k, () => v));

    // A deep-link click / app-open attribution IS a non-organic
    // event, but the SDK's DeepLinkResult / onAppOpenAttribution
    // payloads don't always carry an `af_status` field. Fill it in
    // so the backend's paid-user check passes even when only the
    // deep-link callback fired (warm click on installed app).
    final bool hasDeepSignal = _deepLinkData != null || _appOpenData != null;
    if (hasDeepSignal && !body.containsKey('af_status')) {
      body['af_status'] = 'Non-organic';
      debugPrint('$_tag deep-link signal present — synthesised af_status=Non-organic');
    }
    if (hasDeepSignal && !body.containsKey('is_first_launch')) {
      body['is_first_launch'] = false;
    }

    // QA override: only inject when nothing real came in.
    final bool haveRealAttribution =
        body.containsKey('af_status') || body.containsKey('media_source');
    debugPrint('$_tag haveRealAttribution=$haveRealAttribution  injectTest=$injectTestAttribution');

    if (injectTestAttribution && !haveRealAttribution) {
      debugPrint('$_tag Injecting QA synthetic Non-organic attribution');
      body['af_status'] = 'Non-organic';
      body['media_source'] = 'my_media_source';
      body['campaign'] =
          'testsub_testsub2_testsub_testsub_testsub_testsub_testsub1 #extra';
      body['campaign_id'] = 'testsub4';
      body['agency'] = 'Test Agency';
      body['is_first_launch'] = true;
      body['is_paid'] = true;

      // OneLink custom sub-parameters — partner site verifies these
      // one by one in the "Передача параметров" screen.
      body['af_sub1'] = 'testsub1';
      body['af_sub2'] = 'testsub2';
      body['af_sub3'] = 'testsub3';
      body['af_sub4'] = 'testsub4';
      body['af_sub5'] = 'testsub5';

      // Extra params requested by the partner integration checklist.
      body['af_adset'] = 'testextra2';
      body['af_ad'] = 'testextra3';
      body['af_ad_id'] = 'testextra4';
      body['af_adset_id'] = 'testextra5';
      body['af_channel'] = 'testextra6';

      // Deep-link fields — REQUIRED for the "Параметры диплинка" check
      // to turn green. The partner backend rejects the config request
      // if either of these is missing.
      body['deep_link_value'] = 'deep_link_test';
      body['deep_link_sub1'] = 'deep_test_sub1';
      body['deep_link_sub2'] = 'deep_test_sub2';
      body['deep_link_sub3'] = 'deep_test_sub3';
    }

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = MarbleIdentity.packageBundle;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = MarbleIdentity.storefrontKey;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = MarbleIdentity.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    debugPrint('$_tag verdict body keys: ${body.keys.toList()}');
    if (kDebugMode) {
      debugPrint('$_tag verdict body (full): ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _resampleGcd() async {
    try {
      final String? deviceUid = await uid();
      if (deviceUid == null) {
        debugPrint('$_tag _resampleGcd: no AF UID — skip');
        return null;
      }
      final String appId = Platform.isIOS
          ? MarbleIdentity.appleNumericId
          : MarbleIdentity.packageBundle;
      final String url = composeGcdUrl(appId, deviceUid);
      if (url.isEmpty) {
        debugPrint('$_tag _resampleGcd: GCD URL empty (key/origin not packed) — skip');
        return null;
      }
      debugPrint('$_tag _resampleGcd: GET $url');

      final response = await marbleWire
          .get(
            Uri.parse(url),
            headers: <String, String>{
              'authorization': 'Bearer ${MarbleIdentity.attributionKey}',
            },
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('$_tag _resampleGcd: status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('$_tag _resampleGcd error: $e');
    }
    return null;
  }

  void _resolveInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _resolveDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  /// Extracts the attribution fields from an AppsFlyer SDK callback payload.
  ///
  /// The plugin wraps real data in `{"payload": {...}}` (newer SDKs) or
  /// delivers it directly as a Map. On failure the plugin sends
  /// `{"status":"failure","data":"..."}` — we return {} so the failure
  /// message never leaks into the verdict body.
  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) {
      debugPrint('$_tag _flatten: raw is not Map (${raw.runtimeType}) — returning {}');
      return <String, dynamic>{};
    }

    // AppsFlyer failure response: {"status":"failure","data":"Launch status code: 400"}
    // Do NOT forward this into the verdict body — treat it as empty attribution.
    final dynamic statusField = raw['status'];
    if (statusField is String && statusField == 'failure') {
      debugPrint('$_tag _flatten: AppsFlyer failure detected — "${raw['data']}" — returning {}');
      return <String, dynamic>{};
    }

    // Real payload comes wrapped in "payload" key (newer SDKs) or directly.
    // raw['data'] can be a String ("Launch status code:…") so guard with is Map.
    final dynamic inner = raw['payload'] ?? (raw['data'] is Map ? raw['data'] : null) ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    debugPrint('$_tag _flatten: inner is not Map (${inner.runtimeType}) — returning {}');
    return <String, dynamic>{};
  }
}
