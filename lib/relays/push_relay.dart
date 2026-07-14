import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_store.dart';
import 'ua_stamp.dart';

// ============================================================
// PUSH RELAY — Firebase Messaging + local notification renderer
// ============================================================
// - Cold-start tap (app was killed):     link is STASHED so the shell
//                                        picks it up on next boot.
// - Warm tap (background / foreground):  link is delivered live via
//                                        [onLink] callback (NOT saved).
//
// The Android channel id below must EXACTLY match the manifest
// meta-data `default_notification_channel_id`. The small icon is the
// dedicated flame vector — NEVER reuse the launcher silhouette.
// ============================================================

const String kChannelId = 'marble_dispatch_channel';
const String kChannelName = 'Marble Descent Alerts';
// Resource name only — flutter_local_notifications resolves it
// against `android/app/src/main/res/drawable/`. The `@drawable/`
// prefix is XML-syntax only and would make Android silently fall
// back to the launcher icon.
const String _smallIconRes = 'ic_notification';
const String _tag = '[PushRelay]';

@pragma('vm:entry-point')
Future<void> _bgIsolate(RemoteMessage message) async {
  // The system renders background notifications by itself. Tap is
  // handled on resume (warm) or on boot (cold) — nothing to do here.
}

class PushRelay {
  PushRelay(this._store);

  final LocalStore _store;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _online = false;

  /// Warm-tap link delivery for the WebView.
  void Function(String link)? onLink;

  /// Notified when FCM rotates the token → the router should re-POST
  /// the verdict body so the backend sees the new token.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> boot() async {
    // Fully booted and token present — nothing to do.
    if (_online && _token != null) return;

    debugPrint('$_tag boot()');

    // Infrastructure is already wired (listeners, channel) but the token was
    // null on the first attempt (offline first-launch). Re-fetch now that the
    // caller is presumably online again; no duplicate listener registrations.
    if (_online && _fm != null) {
      try {
        _token = await _fm!.getToken();
        debugPrint('$_tag token re-fetch → '
            '${_token == null ? "null" : "${_token!.substring(0, 12)}…"}');
      } catch (e) {
        debugPrint('$_tag token re-fetch error: $e');
      }
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgIsolate);

      await _prepareLocal();

      _token = await _fm!.getToken();
      debugPrint('$_tag FCM token: ${_token == null ? "null" : "${_token!.substring(0, 12)}…"}');

      _fm!.onTokenRefresh.listen((String fresh) {
        debugPrint('$_tag token refreshed: ${fresh.substring(0, 12)}…');
        _token = fresh;
        onTokenRotated?.call(fresh);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? cold = await _fm!.getInitialMessage();
      if (cold != null) {
        debugPrint('$_tag cold-start message: data=${cold.data}');
        _onColdTap(cold);
      } else {
        debugPrint('$_tag no cold-start message');
      }

      _online = true;
      debugPrint('$_tag boot() done');
    } catch (e) {
      // Firebase not configured yet (no google-services.json). Push
      // stays dormant, the shell keeps working without it.
      debugPrint('$_tag boot() error (Firebase not ready?): $e');
    }
  }

  Future<void> _prepareLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIconRes);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) onLink?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: 'Updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS permission. Records
  /// an "OS denied" flag so the invite screen never loops.
  Future<bool> askPermission() async {
    if (_fm == null) {
      debugPrint('$_tag askPermission() — FM null, returning false');
      return false;
    }
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    debugPrint('$_tag askPermission() → status=$status  granted=$granted');

    await _store.setPushGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _store.markPushOsDenied();
    }
    return granted;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    debugPrint('$_tag _onForeground: title="${message.notification?.title}"  data=${message.data}');
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _downloadImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kChannelId,
      kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIconRes,
    );

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    debugPrint('$_tag _onColdTap: link=$link');
    if (link != null && link.isNotEmpty) {
      _store.stashColdPush(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    debugPrint('$_tag _onWarmTap: link=$link');
    if (link != null && link.isNotEmpty) {
      onLink?.call(link);
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final res = await marbleWire
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      debugPrint('$_tag _downloadImage: ${res.statusCode} ${url.length > 60 ? url.substring(0, 60) : url}');
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (e) {
      debugPrint('$_tag _downloadImage error: $e');
    }
    return null;
  }
}
