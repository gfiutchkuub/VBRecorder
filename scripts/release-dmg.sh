#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build/ReleaseDerivedData"
BUILD_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/VBRecorder.app"
DIST_DIR="${ROOT_DIR}/dist"
STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_PATH="${DIST_DIR}/VBRecorder.dmg"

xcodebuild build \
  -project "${ROOT_DIR}/VBRecorder.xcodeproj" \
  -scheme VBRecorder \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}"

if [[ ! -d "${BUILD_APP_PATH}" ]]; then
  echo "Release build succeeded but app bundle was not found: ${BUILD_APP_PATH}" >&2
  exit 1
fi

rm -rf "${STAGING_DIR}"
rm -f "${DMG_PATH}"
mkdir -p "${STAGING_DIR}" "${DIST_DIR}"

cp -R "${BUILD_APP_PATH}" "${STAGING_DIR}/VBRecorder.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "VBRecorder" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGING_DIR}"

echo
echo "Created DMG:"
echo "  ${DMG_PATH}"
