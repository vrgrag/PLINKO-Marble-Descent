# Marble Descent — Battle-Tested Pitfalls

Concrete traps that bit during the initial gray-flow integration of
Marble Descent (July 2026). Each section: symptom → cause → fix.

---

## 1. `androidx.core:core-ktx:1.18.0` requires AGP ≥ 8.9.1

### Symptom
```
> 3 issues were found when checking AAR metadata:
    1. Dependency 'androidx.browser:browser:1.9.0' requires
       Android Gradle plugin 8.9.1 or higher.
       This build currently uses Android Gradle plugin 8.7.3.
```

### Cause
Latest AndroidX bumps target AGP 8.9.x. The Flutter template's default
AGP (currently 8.7.3) is now too old.

### Fix
Pin AGP to 8.9.3+ in `android/settings.gradle.kts`:
```kotlin
id("com.android.application") version "8.9.3" apply false
```

---

## 2. `compileSdk` mismatch across plugin subprojects

### Symptom
```
> Dependency ':flutter_plugin_android_lifecycle' requires libraries
  and applications that depend on it to compile against version 36
  or later of the Android APIs.
```

### Fix
Force every Android library subproject to compile against 36+.
Registered in the top-level `subprojects { … }` block **before**
`evaluationDependsOn(":app")`, otherwise Gradle refuses the callback:

```kotlin
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) compileSdk = 36
            }
    }
}

subprojects { project.evaluationDependsOn(":app") }
```

Already in `android/build.gradle.kts`.

---

## 3. `flutter_local_notifications` needs core-library desugaring

### Symptom
Runtime crash referencing `java.time.*` on API < 26, or:
```
> Could not resolve all files for configuration ':app:debugRuntimeClasspath'.
  Cannot find a version of 'com.android.tools:desugar_jdk_libs' …
```

### Fix
In `android/app/build.gradle.kts`:
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## 4. Kotlin incremental cache fails across drives (Windows)

### Symptom
```
> Could not close incremental caches in D:\…
  because their state does not match the previously observed state.
```
Happens when the project lives on `D:` and the pub cache on `C:`.

### Fix
```properties
# android/gradle.properties
kotlin.incremental=false
```

Trivial cost in incremental time; required on this machine.

---

## 5. VPN transitions flash the offline screen

### Cause
`connectivity_plus` briefly emits `[ConnectivityResult.none]` while the
VPN adapter comes up. `WebVeil` reacts instantly → offline flicker.

### Fix
- Whitelist `ConnectivityResult.vpn`, `.bluetooth`, `.other` in
  `NetProbe._liveAdapters`.
- Debounce the connectivity stream by 700 ms in `WebVeil.initState`
  before opening the offline veil.
- Keep the DNS probe timeout at 7 s in `NetProbe.isConnected`.

All already in place — never remove them.

---

## 6. `ERR_NAME_NOT_RESOLVED` shows the native Android error page

### Symptom
Black canvas + tiny Android-robot icon for 2–7 s before our styled
offline veil appears.

### Fix (in `WebVeil.onWebResourceError`)
1. Set `_spinner = true` IMMEDIATELY so the empty WebView is covered.
2. For DNS / disconnect error codes (`-105`, `-106`, `-21`, or the
   descriptions containing `name_not_resolved` / `internet_disconnected`
   / `network_changed`), open the offline veil DIRECTLY — do NOT
   re-probe DNS first.

Non-DNS errors still go through `_verifyThenOpenOffline()`.

---

## 7. WebView keyboard covers the focused input

The **three-layer** fix (all three required):

1. `AndroidManifest.xml` → `android:windowSoftInputMode="adjustResize"`
2. `WebVeil` Scaffold → `resizeToAvoidBottomInset: false`
3. `_mendKeyboardScroll()` JS injection with `behavior: 'auto'` and a
   single 350 ms `setTimeout` after `focusin`.

Never change `adjustResize` to `adjustPan`. Never enable
`resizeToAvoidBottomInset` on this screen.

---

## 8. Safe-area white bars on notched Android

Handled by `_neutraliseSafeArea()` in `WebVeil.onPageFinished`. Zeroes
out every `--safe-area-inset-*` CSS variable and forces
`viewport-fit=contain`. Re-applied on SPA route changes and every 2.5 s
as a safety net.

Guard: skips application when the keyboard is open (avoids a mid-anim
layout recalc that Samsung / MIUI WebViews handle poorly).

---

## 9. `AppMode.fresh` committed to `native` on network failure

### Cause
Naive check `if (!echo.approved) writeMode(native)` — a network error
returns `approved: false` too. Result: a first offline install traps
the user in the game FOREVER, even after they enable Wi-Fi.

### Fix
`RoutePilot._freshBoot()` only writes `RuntimeMode.native` when the
rejection came from a REAL backend response (`_looksLikeNetworkError`
returns false).

Never simplify this branch.

---

## 10. Push URL saved on warm tap

### Cause
Saving `data.url` on both cold and warm taps causes the app to keep
loading yesterday's push URL forever, even after fresh verdict runs.

### Fix
- Cold tap only → `LocalStore.stashColdPush(url)`.
- Warm tap only → `pushRelay.onLink?.call(url)` (transient, no save).

Both branches already coded — do not merge them.

---

## 11. `FCM token` null at first launch

Not a bug — a race on the very first cold start. `PushRelay.boot`
awaits `getToken()`, but on some devices the token arrives moments
later via `onTokenRefresh`. In that case the initial verdict body has
no `push_token` field; the token is sent on the next launch OR
immediately after via the `onTokenRotated` re-post callback.

**Never** send `push_token: ""` or `push_token: null` — omit the field
entirely.

---

## 12. Icon looks cropped in the launcher

### Fix
`pubspec.yaml`:
```yaml
flutter_launcher_icons:
  adaptive_icon_foreground: "assets/icon2.png"
  adaptive_icon_foreground_inset: 24
```

Inset of 24 shrinks the foreground to ~52 % of the adaptive canvas,
comfortably inside the 66 % safe zone. Icon2 is preserved without
edge clipping on any Pixel / Samsung / MIUI mask.

Re-generate with:
```powershell
dart run flutter_launcher_icons
```

Verify with `adb shell pm clear com.google.android.apps.nexuslauncher`
then re-open the launcher (the icon cache survives reinstalls).

---

## 13. Google Play `versionCode` collision on second submission

Bump BOTH:
```yaml
# pubspec.yaml
version: 1.0.1+2
```
```kotlin
// android/app/build.gradle.kts
defaultConfig {
    versionCode = 2
    versionName = "1.0.1"
}
```

Marble Descent's `build.gradle.kts` hard-codes these values (per
signing convention on this account) — do not switch to
`flutter.versionCode` without also removing the hard-code.

---

## 14. `GeneratedPluginRegistrant.java` gets stale after plugin swap

### Symptom
```
GeneratedPluginRegistrant.java:34: error: cannot find symbol
  new com.mr.flutter.plugin.filepicker.FilePickerPlugin();
```

Even after `flutter pub get` — the registrant is not overwritten.

### Fix
```powershell
cd android; .\gradlew.bat --stop; cd ..
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java -ErrorAction SilentlyContinue
flutter clean
flutter pub get
```

---

## 15. Quick-recovery cookbook

Whenever the Android side gets weird:

```powershell
cd android
.\gradlew.bat --stop
cd ..
flutter clean
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java -ErrorAction SilentlyContinue
flutter pub get
flutter build apk --debug          # smoke-test compile
flutter build apk --release --obfuscate --split-debug-info=build\debug_info
```

---

## Pre-release checklist

- [ ] `com.marbdesc.marbledescent` matches `applicationId`, `namespace`,
      MainActivity package, and `google-services.json` `package_name`
- [ ] Notification icon is a flame (`ic_notification.xml`), NOT the
      launcher silhouette
- [ ] Launcher icon fully visible on Pixel / Samsung mask (adaptive
      inset ≥ 20)
- [ ] `LocalStore` push OS-denied flag is respected — invite screen
      does not loop
- [ ] Skip cool-down = 3 days (`inviteSkipCooldown`)
- [ ] AppsFlyer + Firebase byte arrays populated in
      `lib/glyph/glyph_pack.dart`
- [ ] `versionCode` bumped from any previous store submission
- [ ] Release built with `--obfuscate --split-debug-info=build/debug_info`
- [ ] `build/debug_info/`, `google-services.json`, `keystore.properties`
      not committed
