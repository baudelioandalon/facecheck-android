#!/usr/bin/env bash
#
# Regenera facecheck-android/mirror/ a partir de facecheck-kmp.
#
#   tools/sync-from-kmp.sh <ruta-o-url-de-facecheck-kmp>            # reescribe el espejo
#   tools/sync-from-kmp.sh <ruta-o-url-de-facecheck-kmp> --check    # solo verifica, no escribe
#
# Ejemplos:
#   tools/sync-from-kmp.sh ../facecheck-kmp
#   tools/sync-from-kmp.sh https://github.com/borealnetwork/facecheck-kmp.git --check
#
# QUÉ HACE
#
#   Copia byte por byte commonMain + androidMain + commonTest del módulo
#   :facecheck-kmp a mirror/, saltándose los dos únicos archivos que un módulo
#   Android puro no puede compilar (los `expect`/`actual` de CameraHost), y
#   escribe MIRROR.lock con el sha256 de cada archivo copiado.
#
#   No transforma código. Si algún día hiciera falta transformarlo, la respuesta
#   correcta es mover la declaración problemática a CameraHost.kt allá arriba,
#   no meter un sed aquí: un sed sobre código ajeno es exactamente la clase de
#   divergencia silenciosa que este mecanismo existe para evitar.
#
# CUÁNDO FALLA (a propósito)
#
#   - si alguno de los archivos excluidos ya no existe con ese nombre en el
#     upstream (alguien lo renombró y el espejo se quedaría sin la exclusión);
#   - si sobrevive cualquier `expect ` / `actual ` en el árbol copiado;
#   - con --check, si el espejo del repo no coincide con lo que produciría esta
#     corrida.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR_DIR="$REPO_ROOT/facecheck-android/mirror"
LOCK_FILE="$REPO_ROOT/MIRROR.lock"

# Los únicos expect/actual del SDK. El módulo Android los reemplaza por
# equivalentes sin expect/actual bajo src/main/kotlin/, fuera del espejo.
EXCLUDE_COMMON=(
    "kotlin/com/borealnetwork/facecheck/camera/CameraHost.kt"
    "kotlin/com/borealnetwork/facecheck/SubjectId.kt"
)
EXCLUDE_ANDROID=(
    "kotlin/com/borealnetwork/facecheck/camera/CameraHost.android.kt"
    "kotlin/com/borealnetwork/facecheck/SubjectId.android.kt"
)
EXCLUDE_TEST=(
    "kotlin/com/borealnetwork/facecheck/SubjectIdTest.kt"
)

CHECK_ONLY=0
UPSTREAM_ARG="${1:-}"
if [[ "${2:-}" == "--check" ]]; then
    CHECK_ONLY=1
fi
if [[ "$UPSTREAM_ARG" == "--check" ]]; then
    echo "error: falta la ruta o URL de facecheck-kmp" >&2
    exit 2
fi

if [[ -z "$UPSTREAM_ARG" ]]; then
    echo "uso: tools/sync-from-kmp.sh <ruta-o-url-de-facecheck-kmp> [--check]" >&2
    exit 2
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# --- 1. Resolver el upstream -------------------------------------------------

if [[ "$UPSTREAM_ARG" == *://* || "$UPSTREAM_ARG" == git@* ]]; then
    echo "==> clonando $UPSTREAM_ARG"
    git clone --quiet --depth 1 "$UPSTREAM_ARG" "$TMP_ROOT/upstream"
    UPSTREAM="$TMP_ROOT/upstream"
else
    UPSTREAM="$(cd "$UPSTREAM_ARG" && pwd)"
fi

SRC_MODULE="$UPSTREAM/facecheck-kmp/src"
if [[ ! -d "$SRC_MODULE/commonMain" ]]; then
    echo "error: $UPSTREAM no parece un checkout de facecheck-kmp" >&2
    echo "       (no existe facecheck-kmp/src/commonMain)" >&2
    exit 1
fi

UPSTREAM_VERSION="$(sed -n 's/^VERSION_NAME=//p' "$UPSTREAM/gradle.properties" | head -1)"
UPSTREAM_VERSION="${UPSTREAM_VERSION:-desconocida}"

UPSTREAM_REV="no-versionado"
if [[ "$(git -C "$UPSTREAM" rev-parse --show-toplevel 2>/dev/null || true)" == "$UPSTREAM" ]]; then
    UPSTREAM_REV="$(git -C "$UPSTREAM" rev-parse HEAD)"
fi

# --- 2. Comprobar que las exclusiones siguen existiendo allá arriba -----------

for excluded in "${EXCLUDE_COMMON[@]}"; do
    pair="commonMain/$excluded"
    if [[ ! -f "$SRC_MODULE/$pair" ]]; then
        cat >&2 <<EOF
error: el upstream ya no tiene $pair

  Este archivo es el que aísla todo el expect/actual del SDK, y este espejo lo
  excluye por nombre. Si se renombró o se partió, actualiza EXCLUDE_COMMON /
  EXCLUDE_ANDROID en este script antes de volver a sincronizar. Copiarlo tal
  cual rompería la compilación del módulo Android.
EOF
        exit 1
    fi
done
for excluded in "${EXCLUDE_ANDROID[@]}"; do
    pair="androidMain/$excluded"
    if [[ ! -f "$SRC_MODULE/$pair" ]]; then
        cat >&2 <<EOF
error: el upstream ya no tiene $pair

  Este archivo es el que aísla todo el expect/actual del SDK, y este espejo lo
  excluye por nombre. Si se renombró o se partió, actualiza EXCLUDE_COMMON /
  EXCLUDE_ANDROID en este script antes de volver a sincronizar. Copiarlo tal
  cual rompería la compilación del módulo Android.
EOF
        exit 1
    fi
done
for excluded in "${EXCLUDE_TEST[@]}"; do
    pair="commonTest/$excluded"
    if [[ ! -f "$SRC_MODULE/$pair" ]]; then
        cat >&2 <<EOF
error: el upstream ya no tiene $pair

  Este test depende de auxiliares que se excluyen del espejo junto con el
  expect/actual de SubjectId. Actualiza EXCLUDE_TEST y la prueba Android propia
  antes de volver a sincronizar si se renombra o se divide.
EOF
        exit 1
    fi
done

# --- 3. Armar el espejo en un temporal ---------------------------------------

STAGE="$TMP_ROOT/mirror"
mkdir -p "$STAGE/main" "$STAGE/test"

copy_tree() {  # copy_tree <origen> <destino> [rutas-relativas-a-excluir...]
    local from="$1" to="$2"
    shift 2
    mkdir -p "$to"
    local args=(-a)
    for excluded in "$@"; do args+=(--exclude "$excluded"); done
    rsync "${args[@]}" "$from/" "$to/"
}

copy_tree "$SRC_MODULE/commonMain/kotlin" "$STAGE/main/kotlin" \
    "com/borealnetwork/facecheck/camera/CameraHost.kt" \
    "com/borealnetwork/facecheck/SubjectId.kt"
copy_tree "$SRC_MODULE/androidMain/kotlin" "$STAGE/main/kotlin" \
    "com/borealnetwork/facecheck/camera/CameraHost.android.kt" \
    "com/borealnetwork/facecheck/SubjectId.android.kt"
copy_tree "$SRC_MODULE/commonTest/kotlin" "$STAGE/test/kotlin" \
    "com/borealnetwork/facecheck/SubjectIdTest.kt"

cp "$SRC_MODULE/androidMain/AndroidManifest.xml" "$STAGE/main/AndroidManifest.xml"
cp "$UPSTREAM/facecheck-kmp/consumer-rules.pro" "$STAGE/consumer-rules.pro"

# --- 4. Que no sobreviva nada que un módulo Android puro no pueda compilar ----

# Los nombres se reportan relativos al espejo, no al temporal en el que se armó:
# quien lea el error necesita saber qué archivo de facecheck-kmp abrir, no en qué
# carpeta de /var/folders quedó la copia de trabajo.
if leftovers="$(grep -rlE '^[[:space:]]*(internal[[:space:]]+)?(expect|actual)[[:space:]]' "$STAGE" \
                | sed "s|^$STAGE/||" | LC_ALL=C sort || true)" \
   && [[ -n "$leftovers" ]]; then
    cat >&2 <<EOF
error: quedó expect/actual en el espejo:

$leftovers

  (rutas relativas a facecheck-android/mirror; en el upstream viven bajo
   facecheck-kmp/src/commonMain o /androidMain con la misma cola)

  Un módulo com.android.library no compila expect/actual. Mueve esas
  declaraciones a CameraHost.kt / CameraHost.<plataforma>.kt en facecheck-kmp
  (ahí está explicado por qué), o añádelas a las exclusiones de este script y
  dales una implementación propia en facecheck-android/src/main/kotlin.
EOF
    exit 1
fi

# --- 5. MIRROR.lock ----------------------------------------------------------

if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

STAGE_LOCK="$TMP_ROOT/MIRROR.lock"
{
    echo "# Generado por tools/sync-from-kmp.sh. No editar a mano."
    echo "#"
    echo "# Cada línea es <sha256>  <ruta relativa a facecheck-android/mirror>."
    echo "# La tarea Gradle verifyMirror lo revalida en cada ./gradlew check."
    echo "upstream = facecheck-kmp"
    echo "upstream_version = $UPSTREAM_VERSION"
    echo "upstream_rev = $UPSTREAM_REV"
    for excluded in "${EXCLUDE_COMMON[@]}"; do
        echo "excluded = facecheck-kmp/src/commonMain/$excluded"
    done
    for excluded in "${EXCLUDE_ANDROID[@]}"; do
        echo "excluded = facecheck-kmp/src/androidMain/$excluded"
    done
    for excluded in "${EXCLUDE_TEST[@]}"; do
        echo "excluded = facecheck-kmp/src/commonTest/$excluded"
    done
    echo "---"
    (cd "$STAGE" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) | while read -r rel; do
        echo "$(sha256 "$STAGE/$rel")  $rel"
    done
} > "$STAGE_LOCK"

# --- 6. Escribir o verificar -------------------------------------------------

if [[ "$CHECK_ONLY" == 1 ]]; then
    status=0
    if ! diff -ru "$MIRROR_DIR" "$STAGE" > "$TMP_ROOT/diff.txt" 2>&1; then
        echo "error: facecheck-android/mirror/ no coincide con $UPSTREAM_ARG" >&2
        sed -n '1,200p' "$TMP_ROOT/diff.txt" >&2
        status=1
    fi
    if ! diff -u "$LOCK_FILE" "$STAGE_LOCK" >/dev/null 2>&1; then
        echo "error: MIRROR.lock está desactualizado" >&2
        status=1
    fi
    if [[ "$status" == 0 ]]; then
        echo "ok: el espejo coincide con facecheck-kmp $UPSTREAM_VERSION ($UPSTREAM_REV)"
    else
        echo >&2
        echo "  Corre: tools/sync-from-kmp.sh $UPSTREAM_ARG" >&2
    fi
    exit "$status"
fi

rm -rf "$MIRROR_DIR"
mkdir -p "$(dirname "$MIRROR_DIR")"
cp -R "$STAGE" "$MIRROR_DIR"
cp "$STAGE_LOCK" "$LOCK_FILE"

echo "ok: espejo regenerado desde facecheck-kmp $UPSTREAM_VERSION ($UPSTREAM_REV)"
echo "    $(awk '/^---$/{seen=1;next} seen' "$LOCK_FILE" | wc -l | tr -d ' ') archivos en facecheck-android/mirror/"
