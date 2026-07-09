import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../glyph/glyph_pack.dart';

// ============================================================
// UA STAMP — outbound HTTP client with a forged device UA
// ============================================================
// The gate POST, GCD refresh, push image download and the WebView
// all share the same string so partner logs look consistent with
// a real Chrome browser on the actual device. A default Dart UA
// (`Dart/…` / `Flutter/…`) is a giveaway for automated scanners.
//
// The Chrome / WebKit version fragments come from the glyph pack;
// the device model / build tag come from device_info_plus at
// first call to [warmUp].
// ============================================================

class UaStampClient extends http.BaseClient {
  UaStampClient._internal();

  final http.Client _inner = http.Client();
  String _stamp = 'Mozilla/5.0';

  /// The forged UA string (also used by the WebView).
  String get stamp => _stamp;

  Future<void> warmUp() async {
    final String chrome = _fallback(unpackChromeMajor(), '149.0.7220.24');
    final String webkit = _fallback(unpackWebkitTag(), '537.36');

    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await probe.androidInfo;
        final String buildTag = a.display.isNotEmpty ? a.display : a.id;
        _stamp = 'Mozilla/5.0 (Linux; Android ${a.version.release}; '
            '${a.brand} ${a.model} Build/$buildTag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo i = await probe.iosInfo;
        final String os = i.systemVersion.replaceAll('.', '_');
        _stamp = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _stamp = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.231005.007) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _fallback(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _stamp);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Shared client — every networking relay uses this single instance.
final UaStampClient marbleWire = UaStampClient._internal();
