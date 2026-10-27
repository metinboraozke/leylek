import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.leylek.leylek"
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
        applicationId = "app.leylek.leylek"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Yükleme anahtarı iki yerden okunur:
    //   • Codemagic: android_signing ile CM_KEYSTORE_* ortam değişkenleri
    //   • Yerel: android/key.properties (git'e girmez)
    // İkisi de yoksa release derlemesi debug anahtarıyla imzalanır; böyle bir
    // paket Play Store'a yüklenemez ama cihazda denenebilir.
    val keyProps = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    val storePath = System.getenv("CM_KEYSTORE_PATH") ?: keyProps.getProperty("storeFile")

    signingConfigs {
        if (storePath != null) {
            create("upload") {
                storeFile = file(storePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: keyProps.getProperty("storePassword")
                keyAlias = System.getenv("CM_KEY_ALIAS") ?: keyProps.getProperty("keyAlias")
                keyPassword = System.getenv("CM_KEY_PASSWORD") ?: keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
