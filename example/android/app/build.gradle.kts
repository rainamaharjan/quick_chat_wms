plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.quick_chat_wms_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 1. FIXED: Kotlin DSL uses 'isCoreLibraryDesugaringEnabled'
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // 2. FIXED: Cleaned up the deprecation warning by passing the string directly
        jvmTarget = "17" 
    }

    defaultConfig {
        applicationId = "com.example.quick_chat_wms_example"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 3. FIXED: Kotlin DSL requires parentheses and double quotes
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}