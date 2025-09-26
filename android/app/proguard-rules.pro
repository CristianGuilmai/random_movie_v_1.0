# Flutter - Mantener todo lo esencial
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (para evitar errores)
-keep class com.google.android.play.core.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }

# Gson
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remover logs de debug
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Mantener métodos nativos
-keepclasseswithmembernames class * {
    native <methods>;
}

# Mantener clases que usan reflexión
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
