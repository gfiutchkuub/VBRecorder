#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build/DerivedData"

xcodebuild test \
  -project "${ROOT_DIR}/VBRecorder.xcodeproj" \
  -scheme VBRecorder \
  -destination "platform=macOS" \
  -only-testing:VBRecorderTests \
  -derivedDataPath "${DERIVED_DATA_PATH}"
