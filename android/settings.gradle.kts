pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // ─────────────────────────────────────────────────────────────────────────
    // SOLUCIÓN DEFINITIVA: descarga automática de JDK via Foojay
    //
    // Este plugin le dice a Gradle dónde descargar la JDK que le pedimos en
    // jvmToolchain(11) del build.gradle.kts raíz. Sin esto, Gradle busca
    // Java 11 solo en el sistema local, no lo encuentra y falla.
    // Con esto, si no está instalado lo descarga automáticamente de Foojay
    // (el repositorio oficial de JDKs adoptado por Gradle). Funciona en
    // cualquier máquina sin configuración manual ni variables de entorno.
    // ─────────────────────────────────────────────────────────────────────────
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"

    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")