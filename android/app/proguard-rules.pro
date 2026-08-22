# The Flutter Gradle plugin bundles its own consumer rules for the engine and
# GeneratedPluginRegistrant, so the app doesn't need to keep those manually.
# These are the defensive rules for the plugins that don't ship their own
# consumer-rules.pro and use reflection/serialization R8 can't see statically.

# flutter_local_notifications re-schedules alarms through a broadcast receiver
# and boot-completed receiver — both are only ever invoked by the OS, so R8
# has no static call site to keep them reachable from.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# gson (pulled in transitively by several plugins) reflects over model fields
# to (de)serialize — stripping/renaming those fields silently breaks decoding.
-keepattributes Signature,*Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Agora RTC — native iris + Java bindings are loaded via reflection/JNI.
# Without these, R8 fullMode strips them and live class crashes on release.
-keep class io.agora.** { *; }
-keep class com.agora.** { *; }
-keep class org.agora.** { *; }

# mobile_scanner (ML Kit) — barcode pipeline uses reflection.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# geolocator — location callbacks via platform channel.
-keep class com.baseflow.geolocator.** { *; }

# file_picker — SAF handling stripped otherwise.
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# flutter_secure_storage — EncryptedSharedPreferences fallback.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Nexus security channel — .text hash + anti-debug via reflection
-keep class com.nexus.edu.SecurityChannel { *; }
-keep class com.nexus.edu.MainActivity { *; }
