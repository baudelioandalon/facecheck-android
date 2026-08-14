# Changelog

Este archivo sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto usa [versionado semántico](https://semver.org/lang/es/).

Los cambios incompatibles se anuncian aquí y en las notas del release.

**Las versiones van amarradas a las de
[`facecheck-kmp`](https://github.com/baudelioandalon/facecheck-kmp):** la 1.0.0
de aquí es exactamente el mismo código de sesión, red y modelos que la 1.0.0 de
allá. Si un número existe en un repo y no en el otro, algo se salió del proceso
descrito en [README § Cómo se mantiene sincronizado](README.md#cómo-se-mantiene-sincronizado-con-facecheck-kmp).

## [No publicado]

Nada todavía.

## [1.0.0] — 2026-08-13

Candidato preparado localmente; todavía no fue publicado ni etiquetado.

### Cambiado

- **Ruptura de API:** `FaceCheck.enroll` y `FaceCheck.verify` reemplazan el
  parámetro `email` por `subjectId`; el multipart usa exclusivamente
  `subjectId` y los errores son `MISSING_SUBJECT_ID` / `INVALID_SUBJECT_ID`.
- No existen sobrecargas, alias ni compatibilidad para `email`: las
  integraciones deben migrar de forma explícita.

### Agregado

- `SubjectId.generate(apiKey)` crea exactamente
  `sub_<huella>_<aleatorio>` (`^sub_[A-Z2-7]{10}_[A-Za-z0-9_-]{22}$`): la
  huella son los primeros 10 caracteres Base32 de SHA-256 de la llave y el
  sufijo son 16 bytes criptográficamente seguros en Base64URL sin relleno.

### Orden de lanzamiento

1. Desplegar Functions TypeScript y Python con el contrato `subjectId`.
2. Validar `/enroll` y `/verify` en un entorno autorizado con datos sintéticos.
3. Publicar KMP, Swift, Android y CLI 1.0.0.
4. Desplegar el portal con la documentación y el directorio compatibles.

Este orden es una lista de ejecución; este cambio no despliega ni publica nada.

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

[No publicado]: https://github.com/baudelioandalon/facecheck-android/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/baudelioandalon/facecheck-android/releases/tag/v1.0.0
[0.1.0]: https://github.com/baudelioandalon/facecheck-android/releases/tag/v0.1.0
