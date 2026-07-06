# Flutter/Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*

# WebView
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}

# Play Core (referenced by Flutter engine, may not be present)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
