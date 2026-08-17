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

    packaging {
        jniLibs {
            // **Die alte Verpackung, mit Absicht.**
            //
            // Seit Android 6 legt Gradle die `.so`-Dateien **unkomprimiert**
            // ins APK: der Installer muss sie dann nicht entpacken, und die App
            // startet minimal schneller. Der Preis steht im Downloadumfang, und
            // der ist bei Flutter erheblich — `libflutter.so` allein misst
            // unkomprimiert 11,2 MB (gemessen am 17.8.2026).
            //
            // `useLegacyPackaging = true` schaltet auf komprimiert zurueck. Das
            // APK wird deutlich kleiner; dafuer belegt die App nach der
            // Installation etwas mehr Platz, weil die Bibliotheken dann
            // ausgepackt auf dem Geraet liegen.
            //
            // Fuer eine App, die ueber GitHub geladen wird, ist das der richtige
            // Handel: der Download ist das, was jemand merkt. Fuer den Play
            // Store waere es der falsche — dort liefert ein App Bundle ohnehin
            // nur die passende Architektur aus, und Google empfiehlt die neue
            // Verpackung.
            useLegacyPackaging = true
        }
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
            // **Release-Bau, aber mit dem Debug-Schluessel signiert.** Ansage
            // vom 17.8.2026, und der Zwischenschritt ist richtig so.
            //
            // Der Weg dahin ist es wert, festgehalten zu werden: zuerst stand
            // hier `signingConfig = null`, also ein wirklich unsigniertes APK.
            // Das ist der ehrlichste Zustand — und **unbrauchbar**, weil
            // Android ein unsigniertes Paket gar nicht erst installiert, meist
            // ohne verwertbare Meldung. Ein Buendel, das niemand aufspielen
            // kann, ist kein Buendel.
            //
            // Der Debug-Schluessel liegt in `~/.android/debug.keystore` und ist
            // auf jedem Rechner der Welt derselbe. Er taugt deshalb NICHT fuer
            // eine Veroeffentlichung: jeder koennte ein Update signieren, das
            // Android als dieselbe App akzeptiert.
            //
            // Der echte Schluessel liegt bereit (`~/newsdb-keys/`, 4096 Bit,
            // 30 Jahre) und ist absichtlich noch nicht in Gebrauch: ab dem
            // Moment, in dem eine App damit verbreitet ist, ist er nicht mehr
            // austauschbar — geht er verloren, kann niemand mehr ein Update
            // ausliefern. Solange nichts verbreitet ist, kostet ein Wechsel
            // nichts.
            //
            // Was der Wechsel spaeter bedeutet: wer diese Fassung installiert
            // hat, muss sie einmal deinstallieren. Android erkennt eine App mit
            // anderer Signatur nicht als dieselbe.
            signingConfig = signingConfigs.getByName("debug")
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
