# Keep all Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep all native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Keep Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep background services
-keep class id.flutter.flutter_background_service.** { *; }

# Keep overlay window
-keep class flutter_overlay_window.** { *; }

# Keep custom services and receivers
-keep class com.example.sbs.CallOverlayService { *; }
-keep class com.example.sbs.MainActivity { *; }
-keep class com.example.sbs.MethodChannelHandler { *; }
-keep class com.example.sbs.CallStateReceiver { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-keepclassmembers class ** {
    @org.jetbrains.annotations.NotNull <methods>;
    @org.jetbrains.annotations.Nullable <methods>;
}

# Keep Gson/JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep model classes for JSON
-keep class com.example.sbs.models.** { *; }

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep phone state libraries
-keep class android.telephony.** { *; }

# Prevent obfuscation of system alert window
-keep class android.view.WindowManager { *; }
-keep class android.view.WindowManager$LayoutParams { *; }

# Keep reflection-based code
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Don't warn about missing classes from third-party libraries
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
