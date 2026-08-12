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
val admobAppId = System.getenv("SENTINEL_ADMOB_APP_ID")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?: "ca-app-pub-3940256099942544~3347511713"

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
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
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
    // Keep Google advertising native-only. Sentinel owns the bridge and loads
    // the Google runtime only after the app shell is alive.
    implementation("com.google.android.gms:play-services-ads:25.4.0")
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")

    // Force the current stable WorkManager release and use it through
    // Configuration.Provider/on-demand initialization. This removes
    // WorkDatabase creation from process startup and lets Sentinel catch a
    // device/database failure before Google Ads is allowed to initialize.
    implementation("androidx.work:work-runtime:2.11.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
