plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sbs"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"   // Warning is OK, not an error
    }

    defaultConfig {
        applicationId = "com.example.sbs"
        minSdk = flutter.minSdkVersion  // Support Android 5.0 (Lollipop) and above
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        
        // Enable multidex for Android 4.x and 5.x devices
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TEMP debug signing (OK for local release APK)
            signingConfig = signingConfigs.getByName("debug")

            // Disable minification to prevent crashes on other devices
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

/* ✅ THIS WAS MISSING — ADD IT */
dependencies {
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
