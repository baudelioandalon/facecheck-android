import java.security.MessageDigest

plugins {
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.kotlinAndroid)
    alias(libs.plugins.kotlinSerialization)
    `maven-publish`
    signing
}

group = (findProperty("GROUP") as String?) ?: "org.borealnetwork"
version = (findProperty("VERSION_NAME") as String?) ?: "0.1.0"

android {
    namespace = "com.borealnetwork.facecheck"
    compileSdk = libs.versions.android.compileSdk.get().toInt()
    buildToolsVersion = libs.versions.android.buildTools.get()

    defaultConfig {
        minSdk = libs.versions.android.minSdk.get().toInt()
        // También espejado: las reglas de R8 que necesita kotlinx.serialization
        // son parte del contrato del código, no de este build.
        consumerProguardFiles("mirror/consumer-rules.pro")
    }

    // El grueso del módulo vive en mirror/, generado por tools/sync-from-kmp.sh
    // desde facecheck-kmp. src/ es lo poco que este repo escribe a mano.
    sourceSets {
        getByName("main") {
            manifest.srcFile("mirror/main/AndroidManifest.xml")
            kotlin.srcDir("mirror/main/kotlin")
        }
        getByName("test") {
            kotlin.srcDir("mirror/test/kotlin")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.datetime)
    implementation(libs.ktor.client.core)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.json)
    implementation(libs.ktor.client.okhttp)

    // `api`, not `implementation`: AndroidCameraController.attachPreview takes a
    // PreviewView and createCameraController's result is bound to a
    // LifecycleOwner, so both types are part of the surface an integrator
    // compiles against.
    api(libs.androidx.camera.core)
    api(libs.androidx.camera.view)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)

    // Bundled model: no Play Services dependency, no first-run download.
    implementation(libs.mlkit.face.detection)

    testImplementation(kotlin("test"))
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.ktor.client.mock)
}

// -----------------------------------------------------------------------------
// verifyMirror
//
// Recalcula el sha256 de todo mirror/ y lo compara contra MIRROR.lock. Detecta
// la falla más probable de este esquema: alguien arregla un bug editando
// mirror/ directamente, funciona, se sube — y el arreglo desaparece en la
// siguiente sincronización sin que nadie se entere.
//
// Esto NO detecta que el upstream haya avanzado; eso lo hace el job "mirror" de
// CI, que vuelve a correr tools/sync-from-kmp.sh contra facecheck-kmp.
// -----------------------------------------------------------------------------

val verifyMirror by tasks.registering {
    group = "verification"
    description = "Comprueba que facecheck-android/mirror/ coincide con MIRROR.lock."

    val lockFile = rootProject.layout.projectDirectory.file("MIRROR.lock").asFile
    val mirrorDir = layout.projectDirectory.dir("mirror").asFile

    inputs.file(lockFile)
    inputs.dir(mirrorDir)
    outputs.upToDateWhen { false }

    doLast {
        if (!lockFile.isFile) {
            error("Falta MIRROR.lock. Corre tools/sync-from-kmp.sh <ruta-a-facecheck-kmp>.")
        }

        val expected = lockFile.readLines()
            .dropWhile { it.trim() != "---" }
            .drop(1)
            .filter { it.isNotBlank() }
            .associate { line ->
                val parts = line.split("  ", limit = 2)
                parts[1] to parts[0]
            }

        fun sha256(bytes: ByteArray): String =
            MessageDigest.getInstance("SHA-256").digest(bytes)
                .joinToString("") { "%02x".format(it) }

        val actual = mirrorDir.walkTopDown()
            .filter { it.isFile }
            .associate { it.relativeTo(mirrorDir).invariantSeparatorsPath to sha256(it.readBytes()) }

        val changed = expected.keys.intersect(actual.keys).filter { expected[it] != actual[it] }
        val missing = expected.keys - actual.keys
        val extra = actual.keys - expected.keys

        if (changed.isEmpty() && missing.isEmpty() && extra.isEmpty()) return@doLast

        val report = buildString {
            appendLine("facecheck-android/mirror/ no coincide con MIRROR.lock.")
            appendLine()
            if (changed.isNotEmpty()) {
                appendLine("  Modificados a mano:")
                changed.sorted().forEach { appendLine("    $it") }
            }
            if (missing.isNotEmpty()) {
                appendLine("  Borrados:")
                missing.sorted().forEach { appendLine("    $it") }
            }
            if (extra.isNotEmpty()) {
                appendLine("  Añadidos fuera del espejo:")
                extra.sorted().forEach { appendLine("    $it") }
            }
            appendLine()
            appendLine("  mirror/ es código generado: se edita en facecheck-kmp, no aquí.")
            appendLine("  - Si el cambio es tuyo: llévalo a facecheck-kmp y vuelve a sincronizar")
            appendLine("    con tools/sync-from-kmp.sh <ruta-a-facecheck-kmp>.")
            appendLine("  - Si el cambio es de facecheck-kmp: tools/sync-from-kmp.sh regenera")
            appendLine("    mirror/ y MIRROR.lock juntos.")
            appendLine("  - Si de verdad es específico de Android: va en facecheck-android/src/,")
            appendLine("    que está fuera del espejo.")
        }
        error(report)
    }
}

tasks.named("check") {
    dependsOn(verifyMirror)
}

// -----------------------------------------------------------------------------
// Publicación
//
// Degrada a "no hace nada" cuando faltan las credenciales; ver el README.
// -----------------------------------------------------------------------------

val javadocJar by tasks.registering(Jar::class) {
    archiveClassifier.set("javadoc")
}

publishing {
    publications {
        register<MavenPublication>("release") {
            afterEvaluate { from(components["release"]) }
            artifact(javadocJar)

            pom {
                name.set("FaceCheck Android")
                description.set(
                    "SDK de Android para verificación facial con retos de vida en el " +
                        "dispositivo. Build nativo, sin Kotlin Multiplatform.",
                )
                url.set("https://facecheck.borealnetwork.org")
                inceptionYear.set("2026")

                licenses {
                    license {
                        name.set("The Apache License, Version 2.0")
                        url.set("https://www.apache.org/licenses/LICENSE-2.0.txt")
                        distribution.set("repo")
                    }
                }
                developers {
                    developer {
                        id.set("borealnetwork")
                        name.set("Boreal Network")
                        url.set("https://borealnetwork.org")
                    }
                }
                scm {
                    url.set("https://github.com/baudelioandalon/facecheck-android")
                    connection.set("scm:git:https://github.com/baudelioandalon/facecheck-android.git")
                    developerConnection.set(
                        "scm:git:ssh://git@github.com/baudelioandalon/facecheck-android.git",
                    )
                }
            }
        }
    }

    repositories {
        val centralUser = findProperty("mavenCentralUsername") as String?
        val centralPassword = findProperty("mavenCentralPassword") as String?

        if (!centralUser.isNullOrBlank() && !centralPassword.isNullOrBlank()) {
            maven {
                name = "mavenCentral"
                url = uri(
                    "https://ossrh-staging-api.central.sonatype.com" +
                        "/service/local/staging/deploy/maven2/",
                )
                credentials {
                    username = centralUser
                    password = centralPassword
                }
            }
        }

        maven {
            name = "localStaging"
            url = layout.buildDirectory.dir("staging-repo").get().asFile.toURI()
        }
    }
}

signing {
    val signingKey = (findProperty("signingInMemoryKey") as String?)
        ?.replace("\\n", "\n")
    val signingPassword = (findProperty("signingInMemoryKeyPassword") as String?) ?: ""

    isRequired = !signingKey.isNullOrBlank()
    if (!signingKey.isNullOrBlank()) {
        useInMemoryPgpKeys(signingKey, signingPassword)
        sign(publishing.publications)
    }
}

tasks.withType<AbstractPublishToMaven>().configureEach {
    dependsOn(tasks.withType<Sign>())
}