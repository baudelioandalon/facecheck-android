# FaceCheck Android

SDK nativo de **Android** para el servicio de verificación facial
[FaceCheck](https://facecheck.borealnetwork.org).

Hace tres cosas, y solo tres:

1. **Guía al usuario** con una sesión de retos de vida en pantalla ("gira la
   cabeza a la izquierda", "mira de frente") hasta conseguir una foto frontal,
   nítida y bien iluminada.
2. **Captura esa foto** con la cámara frontal, usando CameraX y el detector
   facial empaquetado de ML Kit.
3. **La sube** al backend de FaceCheck, que decide si corresponde a la persona
   registrada.

El SDK **no decide nada**. La comparación, el umbral y el veredicto viven en el
servidor; el dispositivo nunca ve un score ni un umbral. Un `VerifyResult` con
`verified = true` es la respuesta del backend, no una conclusión del teléfono.

| | |
|---|---|
| Artefacto | `org.borealnetwork:facecheck-android` |
| Paquete | `com.borealnetwork.facecheck` |
| Versión | `1.0.0` |
| Licencia | Apache 2.0 |
| `minSdk` | 24 |
| `compileSdk` | 36 |

## ¿Este o `facecheck-kmp`?

Este repo es la **distribución solo-Android** de
[`facecheck-kmp`](https://github.com/baudelioandalon/facecheck-kmp). Misma API,
misma numeración de versiones, mismo código: una AAR normal, sin metadatos
`.module` de Kotlin Multiplatform y sin `expect`/`actual`.

- **Usa `facecheck-android`** si tu app es solo de Android y no quieres KMP en
  tu build.
- **Usa `facecheck-kmp`** si compartes código con iOS.

Cómo se mantienen idénticos está explicado abajo, en
[Cómo se mantiene sincronizado](#cómo-se-mantiene-sincronizado-con-facecheck-kmp).
Léelo antes de tocar nada bajo `facecheck-android/mirror/`.

---

## Instalación

En `gradle/libs.versions.toml`:

```toml
[versions]
facecheck = "1.0.0"

[libraries]
facecheck-android = { module = "org.borealnetwork:facecheck-android", version.ref = "facecheck" }
```

En el módulo:

```kotlin
dependencies {
    implementation(libs.facecheck.android)
}
```

O directo, sin catálogo:

```kotlin
implementation("org.borealnetwork:facecheck-android:1.0.0")
```

El SDK arrastra CameraX y el detector facial de ML Kit **empaquetado** (no el de
Play Services): no necesita cuenta de Google en el dispositivo ni descarga el
modelo en el primer arranque, a cambio de ~3 MB de APK.

El permiso de cámara ya viene declarado en el manifest de la librería; pedírselo
al usuario en tiempo de ejecución sigue siendo trabajo de tu app.

---

## Ejemplo

```kotlin
// Una sola vez, al arrancar la app.
FaceCheck.initialize(
    FaceCheckConfig(
        apiKey = "lk_test_…",                                   // del portal
        baseUrl = "https://us-central1-facecheck-mx.cloudfunctions.net",
    ),
)

// Por sesión.
val camera = AndroidCameraController(host = CameraHost(activity))
camera.attachPreview(previewView)

// Se construye antes de arrancar para poder pintar la primera instrucción
// de inmediato, en vez de una pantalla vacía hasta el primer cuadro.
val machine = FaceCheck.newChallengeMachine()
lifecycleScope.launch {
    machine.state.collect { statusView.text = it.instructionEs }
}

lifecycleScope.launch {
    try {
        val result = FaceCheck.verify(
            subjectId = "sub_ABCDEFGHIJ_abcdefghijklmnopqrstuv",
            camera = camera,
            machine = machine,
        )
        statusView.text = if (result.verified) {
            "Verificado"
        } else {
            result.messageEs ?: "No coincide"
        }
    } catch (e: FaceCheckException) {
        statusView.text = "${e.code}: ${e.message}"
    } finally {
        camera.close()
    }
}
```

Un rostro que simplemente **no coincide** no es una excepción: regresa como
`VerifyResult(verified = false)` con una razón. `FaceCheckException` es para
sesiones de vida fallidas, problemas de red y peticiones rechazadas.

Para registrar el rostro de referencia de alguien se usa `FaceCheck.enroll(...)`.
Con una llave `lk_live_` hace falta además un **grant** firmado por tu propio
backend: la llave de API viaja dentro del APK y por lo tanto no prueba nada
sobre quién está llamando. Ver
[Grants de registro](https://facecheck.borealnetwork.org/docs/grants).

Un `subjectId` es opaco y no es un correo. `SubjectId.generate(apiKey)` produce
exactamente `sub_<huella>_<aleatorio>`: 10 caracteres Base32 de SHA-256 de la
llave y 16 bytes criptográficamente seguros como 22 caracteres Base64URL sin
relleno. Guarda el resultado asociado a la cuenta de tu producto.

Un ejemplo completo y compilable vive en el repo multiplataforma:
[`samples/android-quickstart`](https://github.com/baudelioandalon/facecheck-kmp/tree/main/samples/android-quickstart).
Compila contra `facecheck-kmp`, pero la API es la misma línea por línea.

---

## Documentación

- **[Documentación de FaceCheck](https://facecheck.borealnetwork.org/docs)** — la
  fuente principal.
- [Instalación del SDK](https://facecheck.borealnetwork.org/docs/sdk)
- [Referencia de la API del SDK](https://facecheck.borealnetwork.org/docs/sdk/referencia)
- [Retos de vida](https://facecheck.borealnetwork.org/docs/sdk/retos)
- [Grants de registro](https://facecheck.borealnetwork.org/docs/grants)
- [Umbrales y modelo](https://facecheck.borealnetwork.org/docs/umbrales)
- [Códigos de error](https://facecheck.borealnetwork.org/docs/errores)

---

## Limitaciones

Esta sección no es una lista de pendientes. Es lo que el SDK **no** hace, dicho
antes de que alguien construya encima algo que dependa de que sí lo hiciera.

### No hay anti-spoofing pasivo

No existe ningún modelo que mire la foto y dictamine si vino de una cara real o
de una pantalla. El modelo de referencia que se evaluó puntúa "ataque" para
prácticamente cualquier entrada, caras vivas incluidas, así que el backend lo
registra como telemetría y **nunca** decide con él.

En la práctica eso quiere decir:

- `VerifyChecks.livenessEnforced` es `false` en todos los despliegues actuales.
- `VerifyResult.spoofScore` y `EnrollResult.spoofScore` viajan en `null`.
- `VerifyChecks.liveness` es informativo. No lo uses como condición.

Un video en reproducción, una máscara 3D o un deepfake en tiempo real **no** son
detectados por este SDK.

### Los retos de vida corren en el dispositivo y no son un control de seguridad

`ChallengeMachine` se ejecuta en un teléfono que el atacante controla. Todo lo
que ve son unos cuantos números (`yaw`, `pitch`, nitidez, brillo) producidos por
código que corre en ese mismo teléfono. Quien tenga el dispositivo rooteado,
enganche el detector o alimente una cámara virtual no necesita girar la cabeza:
emite `yaw = -30f` y el reto pasa. Ni más retos ni umbrales más estrictos
cambian eso, porque el problema no es qué valores se exigen sino **quién los
calcula**.

Para lo que sí sirve:

- **Guiar.** Lleva a un usuario cooperativo a producir una buena foto frontal.
  Es de lo que depende la precisión de todo el sistema, y es lo que la mayoría
  de la gente falla sin instrucciones.
- **Subir el piso.** Derrota el ataque casual — una foto impresa o una imagen en
  otro teléfono — porque una foto no gira la cabeza.

Un `LivenessState.Done` significa "capturamos una foto usable", nunca "esta
persona es real". El SDK no manda al servidor ninguna afirmación sobre la
sesión de vida, y el servidor no la aceptaría: tomarla como autorización sería
poner la frontera de seguridad dentro del proceso del atacante.

**Si estás autorizando algo con consecuencias** (un movimiento de dinero, un
cambio de credenciales), la verificación facial es una señal más, no la única.
Combínala con controles que no vivan en el dispositivo.

### La comparación contra INE es experimental

`CompareWith.INE` y `CompareWith.BOTH` comparan la selfie contra el retrato de
la credencial registrada. Funciona, pero:

- El umbral del canal INE se calibró contra **una** credencial real. Ese margen
  no es una medición estadística; es una observación.
- Una INE fotografiada es un caso difícil: retrato pequeño, impreso, con
  hologramas y reflejos. Cuando el detector no encuentra el rostro en la
  credencial, la comparación no corre.
- El canal solo se comporta con el modelo ArcFace. Con los modelos ligeros que
  se evaluaron el margen se colapsa casi a cero, es decir, no distingue una
  coincidencia legítima de un falso positivo.
- `CompareWith.INE` a secas **siempre** se amplía a `BOTH` en el backend:
  resolver una verificación con el umbral más flojo de los dos, por sí solo,
  sería una regresión de seguridad. Lo que pides es un mínimo, no un máximo; el
  servidor puede endurecerlo y nunca lo suaviza.

Trátalo como una señal adicional en un flujo supervisado, no como comprobación
documental automática.

### Otras cosas que conviene saber

- **La llave de API no es un secreto.** Va dentro de un APK. El backend está
  diseñado sobre esa premisa: reemplazar un registro exige además una selfie que
  ya coincida con la plantilla guardada, y `/verify` no regresa score. No
  agregues controles que supongan que la llave es confidencial.
- **`/verify` no devuelve similitud, y no la va a devolver.** Un score junto con
  su umbral convierte el endpoint en un oráculo de distancia: quien tenga la
  llave puede optimizar un morph contra ese número hasta llegar a
  `verified = true` contra una plantilla que nunca vio — y la imagen resultante
  reconstruye aproximadamente el rostro registrado. Los scores sí quedan en el
  dashboard del tenant, donde la persona a la que se está sondeando no los lee.
- **La sesión está fijada en vertical.** Bloquea tu Activity en portrait.
- **Los textos para el usuario final están en español** (`instructionEs`,
  `messageEs`, `hintEs`). No hay localización todavía.

---

## Cómo se mantiene sincronizado con `facecheck-kmp`

Este es el punto delicado del repo. Dos copias del mismo SDK que divergen en
silencio es exactamente el modo de falla que hay que evitar, así que el
mecanismo está montado para que divergir **rompa el build** en lugar de pasar
desapercibido.

### Qué es `mirror/`

```
facecheck-android/
├── mirror/          <- CÓDIGO GENERADO. Copia byte por byte de facecheck-kmp.
│   ├── main/
│   ├── test/
│   └── consumer-rules.pro
└── src/main/        <- Código propio de este repo. Un solo archivo.
```

`facecheck-android/mirror/` sale de `commonMain` + `androidMain` + `commonTest`
del módulo `:facecheck-kmp`, copiado **sin transformar una sola línea**. La
máquina de retos, el cliente HTTP, los modelos y el pipeline de CameraX son
literalmente los mismos bytes en los dos repos.

Se versiona (no está en `.gitignore`) porque este repo tiene que compilar,
publicarse y ser legible en GitHub sin una copia de `facecheck-kmp` al lado.

### La única excepción

`facecheck-android/src/main/kotlin/com/borealnetwork/facecheck/camera/CameraHost.kt`,
unas 20 líneas sin lógica.

En `facecheck-kmp` esas dos declaraciones — la clase `CameraHost` y la función
`createCameraController` — son `expect` en `commonMain` y `actual` en
`androidMain`, porque su tipo cambia de verdad entre Android e iOS. Un módulo
`com.android.library` no compila `expect`/`actual`, así que el script excluye
esos dos archivos y aquí viven sus equivalentes sin la palabra clave, con la
misma firma. Es la costura donde las dos plataformas dejan de parecerse, y es lo
único que existe dos veces.

El script **no transforma código**. Si algún día hiciera falta transformarlo, la
respuesta correcta es mover la declaración problemática a `CameraHost.kt` allá
arriba, no meter un `sed` aquí: un `sed` sobre código ajeno es justamente la
clase de divergencia silenciosa que este mecanismo existe para evitar.

### Qué hacer al cambiar el código común

**Todo cambio a la lógica compartida se hace en `facecheck-kmp`.** Nunca aquí.
El flujo completo:

```bash
# 1. Edita, prueba y commitea en facecheck-kmp.
cd ../facecheck-kmp
$EDITOR facecheck-kmp/src/commonMain/kotlin/...
./gradlew test

# 2. Regenera el espejo en este repo.
cd ../facecheck-android
tools/sync-from-kmp.sh ../facecheck-kmp        # o la URL del repo

# 3. Compila y prueba aquí. Si el cambio tocó expect/actual, el script ya
#    habrá fallado en el paso 2 diciéndotelo.
./gradlew build

# 4. Commitea mirror/ y MIRROR.lock juntos, con un mensaje que apunte al
#    commit de facecheck-kmp.
git add facecheck-android/mirror MIRROR.lock
```

El script acepta una ruta local o una URL de git:

```bash
tools/sync-from-kmp.sh ../facecheck-kmp
tools/sync-from-kmp.sh https://github.com/baudelioandalon/facecheck-kmp.git
tools/sync-from-kmp.sh ../facecheck-kmp --check    # solo verifica, no escribe
```

### Las tres redes de seguridad

Cada una atrapa una falla distinta. Ninguna sobra.

| Qué | Cuándo corre | Qué falla detecta |
|---|---|---|
| **`tools/sync-from-kmp.sh`** | a mano, y en el job `mirror` de CI | Que el upstream haya renombrado un archivo excluido, o que sobreviva un `expect`/`actual` que este módulo no puede compilar. |
| **Tarea Gradle `verifyMirror`** | en cada `./gradlew check` y `./gradlew build` | Que alguien haya editado `mirror/` a mano. Es la falla más probable: se arregla un bug aquí, funciona, se sube, y el arreglo desaparece en la siguiente sincronización sin que nadie se entere. |
| **Job `mirror` de CI** | en cada push y cada lunes | Que `facecheck-kmp` haya avanzado y este repo se haya quedado atrás. `verifyMirror` no puede verlo: solo compara contra `MIRROR.lock`, que también se quedó viejo. |

`MIRROR.lock` guarda el `sha256` de cada archivo espejado más la versión del
upstream de la que salió. Es generado; no se edita a mano.

### Reglas rápidas

- ¿El cambio es de lógica compartida? → **`facecheck-kmp`**, y luego sincroniza.
- ¿El cambio es específico de Android y no tiene sentido en iOS? → aquí, en
  `facecheck-android/src/`, fuera del espejo.
- ¿`verifyMirror` está fallando? → no edites `MIRROR.lock` para callarlo. O
  lleva tu cambio al upstream, o vuelve a correr el script.
- ¿Vas a publicar? → **la misma versión en los dos repos, con el espejo al
  día.** Que `1.0.0` signifique el mismo código en `facecheck-kmp` y en
  `facecheck-android` es todo el punto.

---

## Compilar

Requiere **JDK 21** y el SDK de Android con `platforms;android-36` y
`build-tools;36.1.0`.

```bash
./gradlew build -x test      # incluye verifyMirror
./gradlew test
```

Las versiones de build-tools y de plataforma están fijadas en
`gradle/libs.versions.toml` a propósito: en una máquina nueva el build falla
diciendo qué instalar, en vez de bajarse solo un componente bajo una licencia
que nadie aceptó. Las versiones de Kotlin, AGP y las librerías deben coincidir
con las de `facecheck-kmp`: el código de `mirror/` se escribió contra ellas.

---

## Publicar

El artefacto va a Maven Central como `org.borealnetwork:facecheck-android`.
**CI no publica**: subir es una acción manual desde una máquina que tenga la
llave GPG.

Las credenciales son *placeholders comentados* en `gradle.properties` y el build
funciona sin ellas — sin credenciales el repositorio remoto ni siquiera se
declara, y sin llave GPG no se firma y tampoco falla. Eso es lo que permite que
una clonación recién hecha compile y publique en local sin configurar nada.

Ponlas en `~/.gradle/gradle.properties` (fuera del repo) o en variables
`ORG_GRADLE_PROJECT_*`:

```properties
mavenCentralUsername=…
mavenCentralPassword=…
signingInMemoryKey=-----BEGIN PGP PRIVATE KEY BLOCK-----\n…
signingInMemoryKeyPassword=…
```

La llave se exporta en una sola línea con `\n` literales:

```bash
gpg --armor --export-secret-keys <KEYID> | awk 'NR>1{printf "\\n"} {printf "%s", $0}'
```

Luego:

```bash
./gradlew publishAllPublicationsToLocalStagingRepository   # ensayo: revisa el POM en build/staging-repo
./gradlew publishToMavenLocal                              # ~/.m2, para probar contra otra app
./gradlew publishAllPublicationsToMavenCentralRepository   # sube de verdad
```

La última tarea **solo existe si hay credenciales**: sin ellas el repositorio
remoto no se declara, y `./gradlew tasks` no ofrece una tarea que fallaría de
todos modos. Si no aparece, es que Gradle no está leyendo tus propiedades.

Después hay que cerrar y liberar el deployment en
[central.sonatype.com](https://central.sonatype.com).

Antes de subir: **resincroniza el espejo y sube la misma versión que
`facecheck-kmp`.**

---

## Contribuir

Ver [`CONTRIBUTING.md`](CONTRIBUTING.md). Lo más importante ya está dicho
arriba: la lógica compartida se edita en `facecheck-kmp`, nunca en `mirror/`.

## Licencia

Apache License 2.0 — ver [`LICENSE`](LICENSE).

Copyright 2026 Boreal Network.
