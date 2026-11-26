plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle plugin, applied after the Android and Kotlin ones.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.youcef.salawati"
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
        applicationId = "com.youcef.salawati"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The APK is signed with the debug key so anyone can install it from a phone
    // without a keystore. It is fine for personal use and sharing with friends;
    // publishing on Play would need a real key.
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
