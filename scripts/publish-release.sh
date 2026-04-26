#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build/ReleaseDerivedData"
BUILD_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/VBRecorder.app"
DIST_DIR="${ROOT_DIR}/dist"
ZIP_PATH="${DIST_DIR}/VBRecorder-app.zip"
DMG_PATH="${DIST_DIR}/VBRecorder.dmg"

TAG="${1:-main-latest}"
TITLE="${2:-VBRecorder ${TAG}}"
NOTES_FILE="${ROOT_DIR}/.build/release-notes.txt"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: https://cli.github.com/" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/release-dmg.sh"

if [[ ! -d "${BUILD_APP_PATH}" ]]; then
  echo "Release app bundle not found: ${BUILD_APP_PATH}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}" "${ROOT_DIR}/.build"
rm -f "${ZIP_PATH}"

ditto -c -k --sequesterRsrc --keepParent "${BUILD_APP_PATH}" "${ZIP_PATH}"

cat >"${NOTES_FILE}" <<EOF
Automated local release publish.

Included assets:
- VBRecorder.dmg
- VBRecorder-app.zip
EOF

if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${DMG_PATH}" "${ZIP_PATH}" --clobber
  gh release edit "${TAG}" --title "${TITLE}" --notes-file "${NOTES_FILE}" --prerelease
else
  gh release create "${TAG}" "${DMG_PATH}" "${ZIP_PATH}" \
    --title "${TITLE}" \
    --notes-file "${NOTES_FILE}" \
    --prerelease
fi

echo
echo "Published release:"
echo "  ${TAG}"
echo "Assets:"
echo "  ${DMG_PATH}"
echo "  ${ZIP_PATH}"
