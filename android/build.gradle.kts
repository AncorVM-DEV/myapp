allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ─────────────────────────────────────────────────────────────────────────────
// SOLUCIÓN JVM — debe ir ANTES de evaluationDependsOn
// ─────────────────────────────────────────────────────────────────────────────
subprojects {
    // Capa 1: toolchain para los módulos que usan el plugin kotlin-android estándar
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            jvmToolchain(17)
        }
    }

    // ── NUEVA CAPA 2: red de seguridad para módulos que se escapan del toolchain ──
    // flutter_timezone (y otros plugins similares) usan una variante del plugin
    // de Kotlin que no queda atrapada por plugins.withId() de arriba.
    // Su compilador de Kotlin sigue usando 1.8 por defecto mientras Java ya va
    // a 17, causando el error "Inconsistent JVM-target compatibility".
    // Este bloque atrapa TODAS las tareas de Kotlin de TODOS los subproyectos
    // y las fuerza a 17, sin importar qué plugin usen internamente.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_17.toString()
        }
    }
}

// Este bloque congela los proyectos — siempre debe ir al final
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}