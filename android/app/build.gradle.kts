import java.util.Properties

plugins {
    id("com.android.application")

    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.abdicobos.pokerdicedash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.github.abdicobos.pokerdicedash"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Own release key only when android/key.properties exists (never committed).
    // Without it the release APK is left unsigned: F-Droid signs its own builds.
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        val keyProps = Properties().apply { keyPropsFile.inputStream().use { load(it) } }
        signingConfigs {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropsFile.exists()) signingConfigs.getByName("release") else null
        }
    }

    // No encrypted Google dependency blob in the APK (F-Droid requirement).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}
