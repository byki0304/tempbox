#!/usr/bin/env bash
set -euo pipefail

# Vercel images do not include Flutter. Download the same SDK this app was built with.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="${ROOT}/.flutter-sdk"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "${SDK_DIR}/flutter/bin/flutter" ]; then
    mkdir -p "${SDK_DIR}"
    ARCHIVE="${SDK_DIR}/flutter.tar.xz"
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o "${ARCHIVE}"
    tar -xJf "${ARCHIVE}" -C "${SDK_DIR}"
    rm -f "${ARCHIVE}"
  fi
  export PATH="${SDK_DIR}/flutter/bin:${PATH}"
fi

export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=*
flutter config --no-analytics --enable-web
flutter precache --web
cd "${ROOT}"
flutter pub get
flutter build web --release
node tool/patch_service_worker.js
