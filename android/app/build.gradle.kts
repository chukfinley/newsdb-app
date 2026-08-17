plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.chuk.newsdb_app"

    // Gemessen am 17.8.2026: `flutter.compileSdkVersion` steht bei dieser
    // Flutter-Fassung auf 36, `flutter_secure_storage` verlangt aber 37 und
    // bricht den Build ab ("requires Android SDK version 37 or higher").
    // Deshalb hier fest 37 statt der Vorgabe. Das ist reines Kompilieren gegen
    // die neuere Schnittstelle und aendert nichts daran, ab welcher
    // Android-Fassung die App laeuft — das entscheidet `minSdk`.
    compileSdk = 37

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.chuk.newsdb_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // **Unsigniert, ausdruecklich.** Ansage vom 17.8.2026: „ein unsigned
            // release ok kein debug".
            //
            // Flutters Vorgabe waere `signingConfigs.getByName("debug")` — ein
            // Release-Buendel, das mit dem Debug-Schluessel unterschrieben ist.
            // Das ist bequem und irrefuehrend: es sieht aus wie ein fertiges
            // APK, traegt aber einen Schluessel, den jede Flutter-Installation
            // auf der Welt hat. Ein spaeterer Wechsel auf den echten Schluessel
            // zwingt danach jeden Nutzer zur Deinstallation, weil Android eine
            // App mit anderer Signatur nicht als dieselbe erkennt.
            //
            // `null` heisst: Gradle legt `app-release-unsigned.apk` ab. Das
            // laesst sich **nicht** ohne Weiteres installieren — genau das ist
            // der ehrliche Zustand, solange es keinen eigenen Schluessel gibt.
            signingConfig = null
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
