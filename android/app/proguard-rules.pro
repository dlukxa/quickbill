# ─────────────────────────────────────────────────────────────────────────────
# Flutter / Dart
# ─────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-dontwarn io.flutter.**

# ─────────────────────────────────────────────────────────────────────────────
# MediaPipe — keep all runtime classes AND suppress missing proto warnings
# The proto classes (CalculatorProfileProto, GraphTemplateProto, etc.) are
# referenced by reflection / JNI at runtime; R8 cannot see them but they are
# bundled in the native .so, so we tell R8 to ignore the missing references.
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Suppress the two specific proto classes that trigger the R8 error
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# ─────────────────────────────────────────────────────────────────────────────
# flutter_gemma
# ─────────────────────────────────────────────────────────────────────────────
-keep class dev.flutter.pigeon.flutter_gemma.** { *; }
-dontwarn dev.flutter.pigeon.flutter_gemma.**

# ─────────────────────────────────────────────────────────────────────────────
# Google ML Kit
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ─────────────────────────────────────────────────────────────────────────────
# Google protobuf (referenced transitively by MediaPipe)
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ─────────────────────────────────────────────────────────────────────────────
# Firebase / Google Play Services
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─────────────────────────────────────────────────────────────────────────────
# Native methods — always keep classes that contain native declarations
# ─────────────────────────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─────────────────────────────────────────────────────────────────────────────
# Suppress obsolete Java 8 source/target warnings (-Xlint:-options)
# These come from third-party libraries compiled with javac --source 8 --target 8.
# R8/D8 will upgrade them transparently; the warnings are safe to suppress.
# ─────────────────────────────────────────────────────────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
