import '../glyph/glyph_pack.dart';
import 'public_links.dart';

// ============================================================
// MARBLE IDENTITY — single point of truth for app-wide constants
// ============================================================
// Identity strings are plain; endpoints / credentials go through
// the glyph codec so plaintext never lands in the binary.
//
// The three identity constants MUST match the following files:
//   • android/app/build.gradle.kts  — applicationId + namespace
//   • android/app/src/main/kotlin/com/marbdesc/marbledescent/MainActivity.kt
//   • android/app/google-services.json (when Firebase lands)  → package_name
//   • android/app/src/main/AndroidManifest.xml → android:label
// ============================================================

class MarbleIdentity {
  MarbleIdentity._();

  // ── Store identity ──
  static const String packageBundle = 'com.marbdesc.marbledescent';
  static const String storefrontKey = 'com.marbdesc.marbledescent';
  static const String publicName = 'Marbale Descent';

  // iOS numeric App Store id — unused on this Android build.
  static const String appleNumericId = '';

  // OneLink template id — the path segment between
  // `<subdomain>.onelink.me/` and the campaign slug.
  // For https://marbledescent.onelink.me/CDuo/hwtomeps this is "CDuo".
  // MUST match the intent-filter pathPrefix in AndroidManifest.xml.
  static const String oneLinkTemplateId = 'CDuo';

  // ── Resolved endpoints / credentials ──
  static String get verdictEndpoint => unpackVerdictEndpoint();
  static String get attributionKey => unpackAttributionKey();
  static String get messagingProject => unpackMessagingProject();

  // ── Public URLs (surface-level, plain) ──
  static const String privacyUrl = kPrivacyLink;
  static const String supportUrl = kSupportLink;
  static const String homeUrl = kBrandSite;

  // ── Timing knobs ──
  // Re-prompt the push invite this many seconds after a Skip (3 days).
  // Per TZ — do not shorten without approval.
  static const int inviteSkipCooldown = 3 * 24 * 60 * 60;

  // Delay before re-querying attribution via the GCD endpoint after
  // the SDK reported a suspicious "Organic" status on install.
  static const int organicResampleDelay = 5;
}
