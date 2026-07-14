plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tiledware.tiled_warfare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tiledware.tiled_warfare"
        minSdk = 21  // Android 5.0 – mature, widely supported
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // For production releases, use the release keystore:
            // 1. Uncomment the signingConfigs block below
            // 2. Set environment variables or use properties
            /*
            signingConfig = signingConfigs.getByName("release")
            */
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("../release-keystore.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: "android"
            keyAlias = "tiled_warfare"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: "android"
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
