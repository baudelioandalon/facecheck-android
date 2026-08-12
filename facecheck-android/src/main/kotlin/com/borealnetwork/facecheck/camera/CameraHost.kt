package com.borealnetwork.facecheck.camera

import android.content.Context

/*
 * ESTE ARCHIVO ES PROPIO DE facecheck-android. No sale del espejo.
 *
 * En facecheck-kmp estas dos declaraciones son `expect` en commonMain y
 * `actual` en androidMain, porque el tipo cambia entre Android e iOS. Un módulo
 * `com.android.library` no compila expect/actual, así que el script de
 * sincronización excluye esos dos archivos y aquí viven sus equivalentes sin la
 * palabra clave.
 *
 * Es lo único del SDK que existe dos veces, y existe dos veces porque es
 * justamente la costura donde las dos plataformas dejan de parecerse. Son 20
 * líneas sin lógica: si cambian allá arriba, el script falla en vez de copiarlas
 * mal. Todo lo demás — la máquina de retos, el cliente HTTP, los modelos, el
 * pipeline de CameraX — es copia byte por byte y está en ../../mirror.
 */

/**
 * On Android the camera hangs off a `Context`.
 *
 * A wrapper rather than a typealias to `Context` so the call site reads the same
 * on both distributions of the SDK: `CameraHost(activity)`.
 *
 * @property context an `Activity` context, not the application context: CameraX
 *   binds to a `LifecycleOwner`, and the application context has no lifecycle to
 *   bind to. Any `ContextWrapper` around an Activity works too.
 */
class CameraHost(val context: Context)

/**
 * CameraX + ML Kit, wired up the way the SDK expects.
 *
 * ```kotlin
 * val camera = createCameraController(CameraHost(activity)) as AndroidCameraController
 * camera.attachPreview(previewView)
 * ```
 *
 * In Android-only code, constructing [AndroidCameraController] directly is
 * equally supported and reads better — no cast. This function exists so that
 * code written against the multiplatform SDK compiles here unchanged.
 *
 * @throws com.borealnetwork.facecheck.model.FaceCheckException
 *   [CAMERA_UNAVAILABLE][com.borealnetwork.facecheck.model.FaceCheckErrorCode.CAMERA_UNAVAILABLE]
 *   if [host] does not wrap a `LifecycleOwner`.
 */
fun createCameraController(
    host: CameraHost,
    options: CameraOptions = CameraOptions(),
): CameraController = AndroidCameraController(host = host, options = options)