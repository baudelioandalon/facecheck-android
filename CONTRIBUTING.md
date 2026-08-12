# Contribuir a FaceCheck Android

Gracias por el interés. Antes de nada, lo único que de verdad hay que entender
de este repo:

> **La lógica compartida NO se edita aquí.** Se edita en
> [`facecheck-kmp`](https://github.com/baudelioandalon/facecheck-kmp) y baja a
> este repo con un script.

`facecheck-android/mirror/` es código generado. Un arreglo hecho directamente
ahí funciona, pasa las pruebas, se sube — y desaparece en la siguiente
sincronización sin que nadie se entere. La tarea Gradle `verifyMirror` existe
para atrapar exactamente eso y va a poner tu build en rojo.

El mecanismo completo está en
[README § Cómo se mantiene sincronizado](README.md#cómo-se-mantiene-sincronizado-con-facecheck-kmp).
Léelo primero.

## Dónde va cada cambio

| Tu cambio | Dónde |
|---|---|
| Máquina de retos, cliente HTTP, modelos, config, pipeline de CameraX | **`facecheck-kmp`**, y luego sincronizas |
| Pruebas de todo lo anterior | **`facecheck-kmp`** (`commonTest`), y luego sincronizas |
| `CameraHost` / `createCameraController` | los dos: aquí `facecheck-android/src/`, allá `CameraHost.kt` + `CameraHost.android.kt` |
| Algo específico de Android que no tiene sentido en iOS | aquí, en `facecheck-android/src/` |
| Build, publicación, CI, documentación de este repo | aquí |
| `mirror/`, `MIRROR.lock` | **nunca a mano** |

Si dudas, va en `facecheck-kmp`. Bajarlo cuesta un comando; sacarlo de aquí
después cuesta un debug de por qué dos SDKs con la misma versión se comportan
distinto.

## Antes de escribir código

- Para **bugs**, abre un issue con la versión del SDK, el `minSdk`, el modelo de
  dispositivo y un caso reproducible. Un stack trace con el `FaceCheckErrorCode`
  ayuda mucho. Si el bug es de lógica compartida, probablemente el issue va en
  `facecheck-kmp`; no pasa nada si te equivocas de repo, se mueve.
- Para **cambios grandes o de API pública**, abre un issue primero, y ábrelo en
  `facecheck-kmp`: la API se decide allá.
- **Nunca pegues llaves de API, grants, ni fotos de personas reales** en un
  issue o un PR.

## Configuración

Necesitas **JDK 21** y el SDK de Android con `platforms;android-36` y
`build-tools;36.1.0`.

```bash
git clone https://github.com/baudelioandalon/facecheck-android.git
cd facecheck-android
./gradlew build -x test      # incluye verifyMirror
./gradlew test
```

Para trabajar en la lógica compartida, clona los dos repos como hermanos:

```
proyectos/
├── facecheck-kmp/
└── facecheck-android/
```

así `tools/sync-from-kmp.sh ../facecheck-kmp` funciona sin argumentos raros.

## Sincronizar

```bash
tools/sync-from-kmp.sh ../facecheck-kmp            # regenera mirror/ y MIRROR.lock
tools/sync-from-kmp.sh ../facecheck-kmp --check    # solo verifica
```

El script falla a propósito si el upstream renombró uno de los dos archivos
excluidos, o si sobrevive un `expect`/`actual` en el árbol copiado (un módulo
`com.android.library` no los compila). Los mensajes de error dicen qué hacer.
No los rodees editando el script sin entender por qué se disparó.

`mirror/` y `MIRROR.lock` se commitean **juntos**, en su propio commit, con un
mensaje que apunte al commit de `facecheck-kmp` del que salieron.

## Estilo

- **Comentarios y KDoc en inglés.** Texto que ve el usuario final en **español
  de México**.
- Los comentarios explican **por qué**, no qué.
- `kotlin.code.style=official`, 4 espacios, línea de ~100 columnas.
- Las versiones de `gradle/libs.versions.toml` deben coincidir con las de
  `facecheck-kmp`. Subir una aquí sin subirla allá es divergencia disfrazada de
  mantenimiento.

## Lo que NO se acepta

Estas no son reglas de estilo; son la razón de ser del diseño. Un PR que haga
cualquiera de estas cosas se cierra aunque el código esté impecable:

- **Editar `mirror/`** en lugar de `facecheck-kmp`.
- **Regenerar `MIRROR.lock`** para silenciar `verifyMirror` sin haber
  resincronizado de verdad.
- **Transformar el código al copiarlo** (un `sed` en el script, un parche). Si
  algo del upstream no compila aquí, se arregla arriba moviéndolo a
  `CameraHost.kt`, o se excluye explícitamente con su equivalente propio en
  `src/`.
- **Devolver un score de similitud desde `/verify`,** o exponerlo en
  `VerifyResult`. Un score junto con su umbral convierte el endpoint en un
  oráculo de distancia contra plantillas que el atacante nunca vio.
- **Poner un umbral de coincidencia en el dispositivo.** Un umbral en el cliente
  es un umbral que el cliente puede cambiar.
- **Tratar el resultado de `ChallengeMachine` como prueba de nada.** Corre en el
  proceso del atacante. Es guía y sube el piso; no es un control de seguridad.
  Ver la sección *Limitaciones* del README.
- **Presentar el anti-spoofing o la comparación contra INE como más maduros de
  lo que son.**

## Pull requests

1. Rama desde `main`.
2. `./gradlew build` y `./gradlew test` en verde localmente. `build` ya corre
   `verifyMirror`.
3. Un cambio por PR. Una sincronización del espejo es su propio PR, o cuando
   menos su propio commit.
4. Actualiza `CHANGELOG.md` bajo `[No publicado]` si el cambio se nota desde
   fuera.
5. Si el PR nace de un cambio en `facecheck-kmp`, enlaza el PR de allá.

Al abrir un PR aceptas que tu contribución se licencie bajo Apache 2.0, igual
que el resto del proyecto.
