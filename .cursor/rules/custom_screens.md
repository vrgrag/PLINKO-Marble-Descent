# Marble Descent — Custom Screen Assets

## MANDATORY: use the project-specific artwork on every shell screen

Three shell screens display dedicated full-screen background artwork
(orientation-aware). Never replace these with generic Flutter widgets,
solid colors, or video placeholders. Always route through
`lib/orbit/asset_book.dart`.

---

## Loading screen (`RoutePilot`)

- Portrait:  `AssetBook.verticalBoot`
              (`assets/marbledesc_veil/Vertical_Loading_Screen.webp`)
- Landscape: `AssetBook.horizontalBoot`
              (`assets/marbledesc_veil/Horizontal_Loading_Screen.webp`)

Overlaid: "Loading…" caption (animated dots on 1200 ms controller) +
`_NeonTrack` progress bar (0 → 1.0, monotonic, hits 1.0 at the exact
route push).

---

## Offline screen (`OfflineVeil`)

- Portrait:  `AssetBook.verticalOffline`
- Landscape: `AssetBook.horizontalOffline`

Overlaid: single **Retry** stadium pill (`SlatePillButton`) centered
horizontally, positioned at ~8 % from the bottom (9 % in landscape).
Width: 66 % of the screen in portrait, 36 % in landscape (does not
cover the artwork's illustration).

---

## Push permission screen (`InviteVeil`)

- Portrait:  `AssetBook.verticalInvite`
- Landscape: `AssetBook.horizontalInvite`

Overlaid, bottom-aligned:
- **Accept** = `SlatePillButton` (magenta→cyan gradient stadium pill).
- **Skip**   = `SlateGhostButton` (outlined black-glass stadium pill —
                proper button, NOT a bare text link).

Both buttons use the same corner radius (999 = full stadium), the same
horizontal padding rail, and their labels use `height: 1.0` so they
sit visually centered.

---

## Notification icon

- File: `android/app/src/main/res/drawable/ic_notification.xml`
- Shape: **flame silhouette**, monochrome white on transparent
- MUST NOT be the launcher icon — silhouette must clearly differ
  (fingerprint safety).

If regenerating, keep it a flame — bells, stars, and generic icons
are rejected per TZ. The current vector's curve differs from every
other project on this account.

---

## Landscape safe area for the WebView

Both `viewPadding.left` and `viewPadding.right` are respected in
landscape (side-mounted camera cutout). `WebVeil` uses a `SafeArea`
wrapper with `bottom: false` around the WebViewWidget.

---

## Asset declarations

Registered in `pubspec.yaml` as the whole folder:

```yaml
flutter:
  assets:
    - assets/marbledesc_veil/
```

Add a new file? Nothing else to do — the whole folder is registered.
