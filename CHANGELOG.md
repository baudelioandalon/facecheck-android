# Changelog

Este archivo sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto usa [versionado semántico](https://semver.org/lang/es/).

Antes de 1.0.0 la API pública puede cambiar en cualquier versión menor. Los
cambios incompatibles se anuncian aquí y en las notas del release.

**Las versiones van amarradas a las de
[`facecheck-kmp`](https://github.com/baudelioandalon/facecheck-kmp):** la 0.1.0
de aquí es exactamente el mismo código de sesión, red y modelos que la 0.1.0 de
allá. Si un número existe en un repo y no en el otro, algo se salió del proceso
descrito en [README § Cómo se mantiene sincronizado](README.md#cómo-se-mantiene-sincronizado-con-facecheck-kmp).

## [No publicado]

Nada todavía.

## [0.1.0] — 2026-08-11

Primera versión pública. Publicada como `org.borealnetwork:facecheck-android`.

Misma API que `facecheck-kmp` 0.1.0, compilada como una librería de Android sin
Kotlin Multiplatform: una AAR normal, sin metadatos `.module` de KMP y sin
`expect`/`actual`.

### Agregado

- `FaceCheck`: punto de entrada con `initialize`, `enroll`, `verify`,
  `newChallengeMachine` y `shutdown`.
- `FaceCheckConfig`, `ChallengeMachine`, `LivenessState`, `CameraController` /
  `AndroidCameraController`, cliente HTTP sobre Ktor y los modelos de respuesta
  (`EnrollResult`, `VerifyResult`, `FaceQuality`, `CompareWith`,
  `FaceCheckException`). Todo espejado byte por byte desde `facecheck-kmp`.
- `CameraHost` y `createCameraController` propios de este repo, sin
  `expect`/`actual`, con la misma firma que en la versión multiplataforma para
  que el código de ejemplo compile igual en las dos.
- `tools/sync-from-kmp.sh`: regenera `facecheck-android/mirror/` desde
  `facecheck-kmp` y escribe `MIRROR.lock`.
- Tarea Gradle `verifyMirror`, enganchada a `check`: falla si alguien editó el
  espejo a mano.

### Limitaciones conocidas

Son de diseño, no pendientes: están explicadas en la sección **Limitaciones**
del [README](README.md#limitaciones).

- No hay anti-spoofing pasivo. `VerifyChecks.livenessEnforced` es `false` en
  todos los despliegues actuales y `spoofScore` viaja en `null`.
- Los retos de vida corren en el dispositivo y no son un control de seguridad.
- La comparación contra la INE (`CompareWith.INE` / `BOTH`) es experimental.

[No publicado]: https://github.com/baudelioandalon/facecheck-android/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/baudelioandalon/facecheck-android/releases/tag/v0.1.0
