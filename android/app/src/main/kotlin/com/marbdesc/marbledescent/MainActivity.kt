package com.marbdesc.marbledescent

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native file-picker bridge for the WebView shell.
 *
 * The web content's <input type="file"> triggers the Android system
 * chooser through this channel and returns the picked content:// URIs
 * back to Dart. Doing it here dodges the file_picker plugin — versions
 * 10+ ship their own Kotlin Gradle Plugin that clashes with Flutter's
 * built-in Kotlin support (see gray_part_pitfalls.md §1).
 */
class MainActivity : FlutterActivity() {

    // Keep in sync with WebVeil._pickerChannel in lib/veil/web_veil.dart.
    private val channelId = "marbdesc/picker_bridge"
    private val chooserCode = 0x4B21

    // Separate channel for launch-intent inspection (see RoutePilot).
    // A OneLink tap while the app is committed to native mode should
    // re-open the gate, so the pilot asks native whether the current
    // Activity was started by a VIEW intent against our OneLink host.
    private val launchChannelId = "marbdesc/launch_intent"

    private var pendingCall: MethodChannel.Result? = null

    // Latest deep-link URI that opened the Activity (cold or warm).
    // Cleared once Dart consumes it so a subsequent plain resume
    // doesn't re-trigger the gate.
    private var launchUri: String? = null

    private var launchChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelId)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectFiles" -> {
                        val many = call.argument<Boolean>("many") ?: false
                        val mimes = call.argument<List<String>>("mimes") ?: emptyList()
                        launchChooser(many, mimes, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // Cache the intent that opened this Activity so Dart can
        // decide whether the pilot must force a fresh boot.
        captureIntent(intent)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launchChannelId)
        launchChannel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunchUri" -> {
                    val u = launchUri
                    launchUri = null
                    result.success(u)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIntent(intent)
        val uri = launchUri
        if (uri != null) {
            launchChannel?.invokeMethod("onDeepLinkArrived", uri)
        }
    }

    private fun captureIntent(i: Intent?) {
        if (i == null) return
        if (i.action != Intent.ACTION_VIEW) return
        val data = i.data ?: return
        val host = data.host ?: return
        // Only interested in our OneLink host — everything else
        // (external browsers, share sheets, etc.) is ignored.
        if (host.endsWith("marbledescent.onelink.me") ||
            host.endsWith("marbledescent.com")) {
            launchUri = data.toString()
        }
    }

    private fun launchChooser(
        many: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Abandon any pending call before starting a new one.
        pendingCall?.success(emptyList<String>())
        pendingCall = result

        val cleaned = mimes.filter { it.contains("/") }
        val pickIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, many)
            when {
                cleaned.isEmpty() -> type = "*/*"
                cleaned.size == 1 -> type = cleaned[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, cleaned.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(pickIntent, null), chooserCode)
        } catch (e: Exception) {
            pendingCall = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooserCode) return

        val callback = pendingCall
        pendingCall = null
        if (callback == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            callback.success(emptyList<String>())
            return
        }

        val collected = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                collected.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { collected.add(it.toString()) }
        }
        callback.success(collected)
    }
}
