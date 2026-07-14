import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../bridge/insight.dart';
import '../relays/local_store.dart';
import '../relays/net_probe.dart';
import '../relays/push_relay.dart';
import '../relays/ua_stamp.dart';
import 'offline_veil.dart';

// ============================================================
// WEB VEIL — immersive full-screen WebView (shell mode UI)
// ============================================================
// Hosts the destination URL with all of the following wired:
//   • forged real-device User-Agent (matches HTTP client)
//   • both orientations, immersive system UI
//   • external-scheme hand-off (tel:, mailto:, market:, etc.)
//   • redirect-loop recovery
//   • live connectivity guard (offline switch is immediate)
//   • warm push link loading
//   • file uploads through the native chooser (no file_picker dep)
//   • third-party cookies + inline media autoplay + DRM auto-grant
//   • safe-area CSS neutraliser + keyboard scroll JS fix
//   • Microsoft Clarity funnel tracking (offer reachability, auth,
//     deposit intents via JS probe + native events)
// ============================================================

const String _tag = '[WebVeil]';

class WebVeil extends StatefulWidget {
  const WebVeil({
    super.key,
    required this.destination,
    required this.store,
    required this.pushRelay,
    required this.netProbe,
  });

  final String destination;
  final LocalStore store;
  final PushRelay pushRelay;
  final NetProbe netProbe;

  @override
  State<WebVeil> createState() => _WebVeilState();
}

class _WebVeilState extends State<WebVeil> with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineOpened = false;
  String? _lastMainFrame;
  int _redirectAttempts = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _offlineDebounce;

  // Clarity funnel state
  bool _offerReached = false;
  bool _pageHadError = false;

  // Must match the channel id in MainActivity.kt.
  static const MethodChannel _pickerChannel =
      MethodChannel('marbdesc/picker_bridge');

  // ── URL pattern matchers ──────────────────────────────────
  static final RegExp _depositRx = RegExp(
    r'(deposit|cashier|top.?up|replenish|payment|checkout|wallet|'
    r'\u043f\u043e\u043f\u043e\u043b\u043d|\u0434\u0435\u043f\u043e\u0437\u0438\u0442|'
    r'\u043a\u0430\u0441\u0441|\u043e\u043f\u043b\u0430\u0442|\u0432\u043d\u0435\u0441\u0442\u0438|'
    r'\u043f\u043b\u0430\u0442\u0435\u0436)',
    caseSensitive: false,
  );
  static final RegExp _registerRx = RegExp(
    r'(sign.?up|regist|create.?account|onboarding|'
    r'\u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446|\u0437\u0430\u0440\u0435\u0433\u0438\u0441\u0442\u0440)',
    caseSensitive: false,
  );
  static final RegExp _loginRx = RegExp(
    r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|'
    r'\u0432\u043e\u0439\u0442\u0438|\u0432\u0445\u043e\u0434|\u0430\u0432\u0442\u043e\u0440\u0438\u0437)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _goImmersive();
    _createController();

    Insight.screen('web');
    Insight.event('web_open');

    widget.pushRelay.onLink = (String link) {
      debugPrint('$_tag warm push link: $link');
      if (mounted) _web.loadRequest(Uri.parse(link));
    };

    _connSub = widget.netProbe.pulses.listen((List<ConnectivityResult> r) {
      final bool everythingNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!everythingNone) {
        _offlineDebounce?.cancel();
        return;
      }
      // Debounce ~700 ms so short VPN transitions or Wi-Fi handoffs
      // don't flicker the offline screen (gray_part_pitfalls.md §3).
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(const Duration(milliseconds: 700), _openOffline);
    });
  }

  void _goImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goImmersive();
      Insight.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      Insight.event('web_background');
    }
  }

  void _createController() {
    debugPrint('$_tag _createController() dest=${widget.destination}');
    debugPrint('$_tag UA: ${marbleWire.stamp}');
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(marbleWire.stamp)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'AegisInsight',
        onMessageReceived: (JavaScriptMessage m) => _onWebSignal(m.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('$_tag onPageStarted: $url');
          _pageHadError = false;
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (String url) {
          debugPrint('$_tag onPageFinished: $url');
          if (mounted) setState(() => _spinner = false);
          _redirectAttempts = 0;
          _neutraliseSafeArea();
          _mendKeyboardScroll();
          _installInsightProbe();
          _trackWebPage(url);
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          debugPrint('$_tag onWebResourceError: code=${err.errorCode}  desc="${err.description}"  url=${err.url}');
          _pageHadError = true;
          final String reason = _classifyWebError(err);
          final String failed = _lastMainFrame ?? widget.destination;
          final String host = Uri.tryParse(failed)?.host ?? '';
          Insight.event('web_error');
          Insight.tag('web_error_reason', reason);
          Insight.tag('web_last_error', '${err.errorCode}:${err.description}');
          if (host.isNotEmpty) Insight.tag('web_error_host', host);
          if (!_offerReached) {
            Insight.event('web_offer_unreachable');
            Insight.tag('offer_reached', 'false');
            Insight.tag('offer_unreachable_reason', reason);
          } else {
            Insight.event('web_error_after_load');
          }

          final String desc = err.description.toLowerCase();
          final bool loop = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectAttempts < 3) {
            _redirectAttempts++;
            debugPrint('$_tag redirect loop detected — retry #$_redirectAttempts → $_lastMainFrame');
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }

          // Cover the WebView with the spinner IMMEDIATELY so the
          // Android system's dark "no page" error page never leaks
          // through (gray_part_pitfalls.md §4).
          if (mounted) setState(() => _spinner = true);

          final bool dnsOrDisconnect =
              desc.contains('name_not_resolved') ||
                  desc.contains('err_name_not_resolved') ||
                  desc.contains('internet_disconnected') ||
                  desc.contains('network_changed') ||
                  err.errorCode == -105 ||
                  err.errorCode == -106 ||
                  err.errorCode == -21;
          if (dnsOrDisconnect) {
            debugPrint('$_tag DNS/disconnect error → openOffline()');
            _openOffline();
          } else {
            debugPrint('$_tag generic error → verifyThenOpenOffline()');
            _verifyThenOpenOffline();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) {
            debugPrint('$_tag onNavigationRequest: unparseable URL — prevent');
            return NavigationDecision.prevent;
          }
          const Set<String> inScheme = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inScheme.contains(uri.scheme)) {
            if (req.isMainFrame) {
              _lastMainFrame = req.url;
              debugPrint('$_tag navigate (main): ${req.url}');
            }
            return NavigationDecision.navigate;
          }
          debugPrint('$_tag external scheme "${uri.scheme}" → openExternal');
          Insight.event('web_external');
          Insight.tag('web_external_scheme', uri.scheme);
          _openExternal(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroidWebView();
    debugPrint('$_tag loadRequest → ${widget.destination}');
    _web.loadRequest(Uri.parse(widget.destination));
  }

  void _tuneAndroidWebView() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _web.platform as AndroidWebViewController;

    // Inline autoplay — no tap-to-start, no fullscreen takeover.
    a.setMediaPlaybackRequiresUserGesture(false);

    // Auto-grant DRM / MIDI-sysex / camera / mic requests so partner
    // sites don't stall behind a modal permission prompt.
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Route site file uploads to the native chooser through the
    // MethodChannel bound in MainActivity.kt.
    a.setOnShowFileSelector(_selectFiles);

    // Third-party cookies keep OAuth / payment sessions alive across
    // redirect chains.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _selectFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _pickerChannel.invokeMethod<List<Object?>>(
        'selectFiles',
        <String, Object>{
          'many': params.mode == FileSelectorMode.openMultiple,
          'mimes': params.acceptTypes
              .where((String t) => t.trim().isNotEmpty)
              .toList(),
        },
      );
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _verifyThenOpenOffline() async {
    if (_offlineOpened) return;
    final bool online = await widget.netProbe.isConnected();
    if (online) return;
    _openOffline();
  }

  void _openOffline() {
    debugPrint('$_tag _openOffline() — _offlineOpened=$_offlineOpened  lastFrame=$_lastMainFrame');
    if (_offlineOpened || !mounted) return;
    _offlineOpened = true;
    final String current = _lastMainFrame ?? widget.destination;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineVeil(
          rebuild: (_) => WebVeil(
            destination: current,
            store: widget.store,
            pushRelay: widget.pushRelay,
            netProbe: widget.netProbe,
          ),
        ),
      ),
    );
  }

  // ── Clarity funnel helpers ────────────────────────────────

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    Insight.screenName('web:${uri == null ? url : '${uri.host}${uri.path}'}');
    Insight.event('web_page');
    Insight.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      Insight.event('web_offer_reached');
      Insight.tag('offer_reached', 'true');
      if (uri?.host != null) Insight.tag('offer_host', uri!.host);
    }
    if (_depositRx.hasMatch(url)) {
      Insight.event('web_cashier_page');
      Insight.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      Insight.event('web_register_page');
      Insight.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      Insight.event('web_login_page');
      Insight.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') || d.contains('connection refused')) {
      return 'connection_refused';
    }
    if (d.contains('too_many_redirects') || d.contains('too many redirects')) {
      return 'redirect_loop';
    }
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) {
      return 'dns_unresolved';
    }
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) {
      return 'no_network';
    }
    if (d.contains('connection_reset')) {
      return 'connection_reset';
    }
    if (d.contains('connection_closed') || d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) {
      return 'ssl_error';
    }
    if (d.contains('blocked')) {
      return 'blocked';
    }
    return 'other';
  }

  // Idempotent probe injected on every onPageFinished. Bridges SPA
  // route changes, deposit/register/login clicks, and auth submits
  // over the AegisInsight JavaScriptChannel.
  void _installInsightProbe() {
    _web.runJavaScript(r'''
(function(){
  if (window.__aegisInsight) return; window.__aegisInsight = true;
  function send(t){ try { AegisInsight.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|\u043f\u043e\u043f\u043e\u043b\u043d|\u0434\u0435\u043f\u043e\u0437\u0438\u0442|\u043a\u0430\u0441\u0441|\u043e\u043f\u043b\u0430\u0442|\u0432\u043d\u0435\u0441\u0442\u0438|\u0432\u044b\u0432\u043e\u0434|\u043f\u043b\u0430\u0442\u0435\u0436)/i;
  var REG=/(sign.?up|regist|create.?account|\u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446|\u0437\u0430\u0440\u0435\u0433\u0438\u0441\u0442\u0440)/i;
  var LOG=/(sign.?in|log.?in|log.?on|\u0432\u043e\u0439\u0442\u0438|\u0432\u0445\u043e\u0434|\u0430\u0432\u0442\u043e\u0440\u0438\u0437)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p);} }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){ var o=history[fn]; history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; }; });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        Insight.event('web_spa_route');
        Insight.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          Insight.event('web_cashier_page');
          Insight.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
        break;
      case 'deposit_click':
        Insight.event('web_deposit_click');
        Insight.tag('deposit_intent', 'true');
        if (data.isNotEmpty) Insight.tag('deposit_label', data);
        break;
      case 'register_click':
        Insight.event('web_register_click');
        Insight.tag('register_intent', 'true');
        break;
      case 'login_click':
        Insight.event('web_login_click');
        Insight.tag('login_intent', 'true');
        break;
      case 'auth_submit':
        if (data == 'register') {
          Insight.event('web_register_submit');
          Insight.tag('attempted_register', 'true');
        } else {
          Insight.event('web_login_submit');
          Insight.tag('attempted_login', 'true');
        }
        break;
      case 'form_submit':
        Insight.event('web_form_submit');
        break;
    }
  }

  // JS: pulls the focused input above the keyboard when it opens.
  // • behavior:'auto' — smooth scroll fights the IME animation.
  // • single 350 ms delay after focusin — 250 ms is too early on
  //   Samsung / MIUI, 500 ms feels sluggish.
  // • visualViewport.resize @120 ms — safety net for OEM keyboards
  //   that don't fire focusin.
  void _mendKeyboardScroll() {
    _web.runJavaScript(r'''
(function(){
  if (window.__mrbKbMend) return; window.__mrbKbMend = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el)) return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20 || r.top<vp.offsetTop){ el.scrollIntoView({behavior:'auto',block:'nearest'}); }
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin', function(e){ if(isField(e.target)) setTimeout(bring, 350); });
  if(window.visualViewport){
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height; if(h < prev) setTimeout(bring, 120); prev = h;
    });
  }
})();
''');
  }

  // JS: neutralise safe-area gaps WITHOUT crushing the partner site's
  // own horizontal padding. See webview_safe_area_injection.mdc:
  //   ✅ overwrite the site's OWN safe-area CSS variables (only bites
  //      if the site actually declares them)
  //   ✅ zero padding-top / margin-top on known top-spacer classes
  //   ❌ NEVER touch padding-left / padding-right on html / body /
  //      #app / #root — that squashes the responsive layout gutters
  //   ✅ skip the whole patch while the keyboard is open (compositor
  //      race)
  //
  // Re-applied on SPA route changes and every 2.5 s as a safety net
  // for lazy-loaded partner sites.
  void _neutraliseSafeArea() {
    _web.runJavaScript(r'''
(function(){
  if(window.__mrbSA) return; window.__mrbSA=true;
  var ID='__mrb_sa';
  var CSS=
    ':root{'+
      '--safe-area-inset-top:0px!important;'+
      '--safe-area-inset-right:0px!important;'+
      '--safe-area-inset-bottom:0px!important;'+
      '--safe-area-inset-left:0px!important;'+
      '--sat:0px!important;--sar:0px!important;'+
      '--sab:0px!important;--sal:0px!important;'+
      '--safe-top:0px!important;--safe-bottom:0px!important;'+
      '--safe-left:0px!important;--safe-right:0px!important;'+
    '}'+
    // Only known decorative top-spacer classes. NEVER html/body/#app/#root.
    '.gameview-mobile-header,.app-header,.js-safe-top,'+
    '.safe-area-top,.has-safe-top{'+
      'padding-top:0!important;'+
      'margin-top:0!important;'+
    '}';
  function kbOpen(){
    if(!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function apply(){
    if(kbOpen()) return;
    var head = document.head || document.documentElement; if(!head) return;
    var m = document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c = (m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c + (c?', ':'') + 'viewport-fit=contain');
    }
    var s = document.getElementById(ID);
    if(!s){ s = document.createElement('style'); s.id = ID; head.appendChild(s); }
    if(s.textContent !== CSS) s.textContent = CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o = history[fn]; history[fn] = function(){
      var r = o.apply(this, arguments);
      setTimeout(apply, 80); setTimeout(apply, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _offlineDebounce?.cancel();
    widget.pushRelay.onLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // The JS scroll fix already handles the IME; letting Flutter also
        // resize would double-relayout and cause visible jitter
        // (webview_keyboard.mdc — Scaffold section).
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Safe zone around the camera cutout in BOTH orientations
            // (top in portrait, side in landscape). System bars are
            // hidden, so only the display-cutout inset remains. No
            // bottom inset — the keyboard is handled in JS.
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF29E7FF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
