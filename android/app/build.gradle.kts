import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing.
//
// The keystore and its passwords live in android/key.properties, which is
// gitignored and must never be committed - see key.properties.example for
// the format. Losing the keystore means never being able to update the app
// on Play under this listing again, so back it up somewhere durable.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

if (!hasReleaseKeystore) {
    logger.warn(
        "No android/key.properties found - release builds will be signed " +
            "with the DEBUG key and cannot be uploaded to Google Play."
    )
}

android {
    namespace = "com.aryanalam.before_you_post"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aryanalam.before_you_post"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no keystore is configured,
            // so a fresh clone can still build and run in release mode.
            //
            // The warning above only reaches the terminal with
            // `flutter build -v`, so do not rely on spotting it. The real
            // safety net is that Play rejects debug-signed uploads: this
            // fails at upload rather than shipping something unsignable.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Without these, R8 aborts the release build over ML Kit text
            // recognisers for scripts this app does not use, and then -
            // once it builds - strips the classes ML Kit loads by
            // reflection, so every detector fails at runtime. See
            // proguard-rules.pro for the detail.
            //
            // AGP 9 removed proguard-android.txt, so the optimising
            // variant is the only default available.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
