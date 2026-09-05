# R8 / ProGuard rules for release builds.
#
# Two separate problems live here, and the first one masks the second.
#
# 1. BUILD FAILURE.
#    google_mlkit_text_recognition supports five scripts and its Java code
#    references the options class for each. We depend on the Latin
#    recogniser only, so the others are genuinely absent and R8 aborts:
#
#      Missing class com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
#
#    Those references sit in a branch the app never takes - the script is
#    chosen in TextRecognitionService and is always Latin. Adding the other
#    four recognisers would pull several MB of models into the APK for
#    languages the rules cannot read anyway.
#
# 2. RUNTIME FAILURE, which is worse because the build succeeds.
#    ML Kit loads much of its implementation by reflection. R8 renames and
#    strips those classes, so a release APK builds cleanly and then throws
#    on every detector:
#
#      PlatformException: Attempt to invoke virtual method
#      'java.lang.Class java.lang.Object.getClass()' on a null object reference
#
#    Silencing the warnings is not enough; the classes have to be kept.
#    Verified by installing a release build and running a real scan -
#    the failure is invisible in debug, where R8 does not run at all.

# --- 1. scripts we do not use -------------------------------------------
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- 2. keep everything ML Kit reaches by reflection ---------------------
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# The Flutter plugin wrappers, which the platform channels look up by name.
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_barcode_scanning.** { *; }

# ML Kit marks reflectively-used members with @Keep; honour it.
-keep @interface androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
