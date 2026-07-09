import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Enable the Google Services plugin only when google-services.json is
// physically present. Keeps the project buildable before Firebase is
// wired up — the shell simply falls back to the offline / game path.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProps = Properties().apply {
    val propsFile = rootProject.file("app/keystore.properties")
    if (propsFile.exists()) load(FileInputStream(propsFile))
}
val hasKeystore = keystoreProps.isNotEmpty()

android {
    namespace = "com.marbdesc.marbledescent"

    // Per TZ §6 → targetSdk 35, minSdk 30. compileSdk stays at 36 for
    // plugin compatibility (see gray_part_pitfalls.md §2).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18+ needs java.time.* on API < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.marbdesc.marbledescent"
        minSdk = 30
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // AppsFlyer needs Play Services Advertising ID (GAID) to attribute
    // the install. Without this dependency the SDK fails to load
    // `com.google.android.gms.ads.identifier.AdvertisingIdClient`
    // via reflection, its CONVERSION endpoint returns HTTP 400, and
    // `onConversionDataFail` fires with an empty payload — so no
    // `af_status` ever reaches the verdict body and the backend
    // permanently answers 404 "No data" on organic installs. See
    // gray_part_flow rules §"Config Request Contract" §3.
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
    // Firebase Installations backs the FCM token registration path
    // AppsFlyer also probes for on cold start.
    implementation("com.google.firebase:firebase-installations:18.0.0")
}

flutter {
    source = "../.."
}
