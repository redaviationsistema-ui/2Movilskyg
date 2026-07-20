import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystoreProperties = Properties()
val releaseKeystoreFile = rootProject.file("key.properties")
if (releaseKeystoreFile.exists()) {
    releaseKeystoreProperties.load(FileInputStream(releaseKeystoreFile))
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested && !releaseKeystoreFile.exists()) {
    throw GradleException(
        "Falta android/key.properties. Configura un keystore externo antes de generar un build release."
    )
}

android {
    namespace = "com.redsky.skygmovil"
    compileSdk = 36
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
    applicationId = "com.redsky.skygmovil"

    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}

    signingConfigs {
        if (releaseKeystoreFile.exists()) {
            create("release") {
                keyAlias = releaseKeystoreProperties["keyAlias"] as String
                keyPassword = releaseKeystoreProperties["keyPassword"] as String
                storeFile = file(releaseKeystoreProperties["storeFile"] as String)
                storePassword = releaseKeystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (releaseKeystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.mlkit:text-recognition:16.0.1")
}
