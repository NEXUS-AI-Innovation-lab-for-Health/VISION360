#!/usr/bin/env bash
# =============================================================================
# Vision360 - Génération de l'APK Android
# =============================================================================
# Enchaîne les vérifications et la compilation, puis copie l'artefact signé
# à la racine du dépôt sous un nom explicite.
#
# Usage :
#   ./build_apk.sh                 # APK universel de release
#   ./build_apk.sh --split         # 3 APK découpés par architecture
#   ./build_apk.sh --debug         # APK de debug (rapide, non distribuable)
#   ./build_apk.sh --bundle        # AAB pour Google Play
#
# Prérequis : Flutter, JDK 17 et Android SDK installés (guide, section 3)
# =============================================================================

set -euo pipefail

# Racine du dépôt = dossier parent de celui-ci
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/mobile_flutter"

MODE="${1:-}"

if [[ ! -d "$APP_DIR" ]]; then
    echo "ERREUR : dossier introuvable : $APP_DIR" >&2
    exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
    echo "ERREUR : flutter n'est pas dans le PATH." >&2
    echo "Voir la section 3 du guide pour l'installation." >&2
    exit 1
fi

cd "$APP_DIR"

# --- Version lue depuis pubspec.yaml, pour nommer l'artefact ----------------
VERSION="$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)"
VERSION="${VERSION:-0.0.0}"

echo "==> Vision360 mobile v$VERSION"
echo

# --- Signature -------------------------------------------------------------
if [[ -f android/key.properties ]]; then
    echo "==> Signature : keystore de release (android/key.properties)"
else
    echo "==> Signature : clé de DEBUG (android/key.properties absent)"
    echo "    L'APK sera fonctionnel mais NON distribuable."
    echo "    Voir la section 6 du guide pour créer un keystore."
fi
echo

# --- Dépendances -----------------------------------------------------------
echo "==> Récupération des dépendances"
flutter pub get

# --- Analyse statique : informative, ne bloque pas la compilation -----------
echo
echo "==> Analyse statique"
flutter analyze || echo "    (avertissements ignorés, poursuite du build)"

# --- Compilation -----------------------------------------------------------
echo
case "$MODE" in
    --debug)
        echo "==> Compilation APK debug"
        flutter build apk --debug
        ARTIFACTS=("build/app/outputs/flutter-apk/app-debug.apk")
        SUFFIX="debug"
        ;;
    --split)
        echo "==> Compilation APK découpés par architecture"
        flutter build apk --release --split-per-abi
        ARTIFACTS=(build/app/outputs/flutter-apk/app-*-release.apk)
        SUFFIX="release"
        ;;
    --bundle)
        echo "==> Compilation App Bundle (AAB)"
        flutter build appbundle --release
        ARTIFACTS=("build/app/outputs/bundle/release/app-release.aab")
        SUFFIX="release"
        ;;
    "")
        echo "==> Compilation APK universel de release"
        flutter build apk --release
        ARTIFACTS=("build/app/outputs/flutter-apk/app-release.apk")
        SUFFIX="release"
        ;;
    *)
        echo "Option inconnue : $MODE" >&2
        echo "Options valides : --split | --debug | --bundle" >&2
        exit 1
        ;;
esac

# --- Copie des artefacts à la racine du dépôt ------------------------------
echo
echo "==> Artefacts produits"
for src in "${ARTIFACTS[@]}"; do
    [[ -f "$src" ]] || continue
    ext="${src##*.}"
    base="$(basename "$src" ".$ext")"

    # app-arm64-v8a-release -> arm64-v8a ; app-release -> (rien)
    abi="$(echo "$base" | sed -E "s/^app-?//; s/-?$SUFFIX$//; s/^-//")"
    name="vision360-v${VERSION}${abi:+-$abi}-${SUFFIX}.${ext}"

    cp "$src" "$REPO_ROOT/$name"
    echo "    $name  ($(du -h "$src" | cut -f1))"
done

echo
echo "Terminé. Les fichiers sont à la racine : $REPO_ROOT"
echo "Installation sur un appareil connecté :"
echo "    adb install -r <fichier>.apk"
