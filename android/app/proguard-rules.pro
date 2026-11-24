# Flutter / Dart engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core (referenced by Flutter deferred components, not bundled)
-dontwarn com.google.android.play.core.**
