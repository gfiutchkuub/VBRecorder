#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build/DerivedData"
APP_SOURCE_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/VBRecorder.app"
APP_INSTALL_PATH="${HOME}/Applications/VBRecorder.app"

xcodebuild build \
  -project "${ROOT_DIR}/VBRecorder.xcodeproj" \
  -scheme VBRecorder \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}"

if [[ ! -d "${APP_SOURCE_PATH}" ]]; then
  echo "Build succeeded but app bundle was not found: ${APP_SOURCE_PATH}" >&2
  exit 1
fi

mkdir -p "${HOME}/Applications"

osascript -e 'tell application id "com.qiaqia.VBRecorder" to quit' >/dev/null 2>&1 || true
sleep 1

rsync -a --delete "${APP_SOURCE_PATH}/" "${APP_INSTALL_PATH}/"

open "${APP_INSTALL_PATH}"

echo
echo "Installed and launched: ${APP_INSTALL_PATH}"
echo "Grant Accessibility once for this fixed path:"
echo "  ${APP_INSTALL_PATH}"
