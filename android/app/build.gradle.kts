import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val requireReleaseSigning = System.getenv("SENTINEL_REQUIRE_RELEASE_SIGNING") == "true"

if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (requireReleaseSigning) {
    throw GradleException(
        "Netsource Sentinel permanent release signing is required, but android/key.properties is missing."
    )
}

android {
    namespace = "com.netsource.sentinel"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.netsource.sentinel"
        // GMA Next-Gen SDK 1.3.0 requires Android API 24 or newer.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("sentinelRelease") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // PR builds may use the runner debug key only for CI validation.
            // Main/manual release builds set SENTINEL_REQUIRE_RELEASE_SIGNING=true
            // and refuse to build unless the permanent Sentinel keystore exists.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("sentinelRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Isolated diagnostic integration: Google's separate GMA Next-Gen SDK.
    // UMP and banner rendering are intentionally excluded from this candidate.
    implementation("com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.3.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
