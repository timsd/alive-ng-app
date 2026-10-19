import java.util.Properties
import java.io.FileInputStream
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.alive.alivengandroidapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID for the ALIVE Nigeria Android app
        applicationId = "com.alive.alivengandroidapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    packaging {
        jniLibs {
            // Allow the Play Store to compress native libs inside the AAB.
            // This reduces per-user download size significantly.
            useLegacyPackaging = false
        }
    }



    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } else {
        // Load from environment variables if key.properties is absent
        val env = System.getenv()
        if (env["ANDROID_STORE_FILE"] != null) {
            keystoreProperties.setProperty("storeFile", env["ANDROID_STORE_FILE"])
        }
        if (env["ANDROID_STORE_PASSWORD"] != null) {
            keystoreProperties.setProperty("storePassword", env["ANDROID_STORE_PASSWORD"])
        }
        if (env["ANDROID_KEY_ALIAS"] != null) {
            keystoreProperties.setProperty("keyAlias", env["ANDROID_KEY_ALIAS"])
        }
        if (env["ANDROID_KEY_PASSWORD"] != null) {
            keystoreProperties.setProperty("keyPassword", env["ANDROID_KEY_PASSWORD"])
        }
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = rootProject.projectDir.parentFile.resolve(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            val hasSigning = keystoreProperties.getProperty("storeFile") != null
            signingConfig = signingConfigs.getByName(if (hasSigning) "release" else "debug")
            // R8 code shrinking + resource shrinking (Play Console "App optimization").
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            ndk {
                // Upload native debug symbols to Play Console for meaningful crash traces.
                // "SYMBOL_TABLE" includes function names; "FULL" adds line numbers but is larger.
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:21.4.0")
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}
    // packaging options not used; resolved native lib duplication by removing conflicting plugin
