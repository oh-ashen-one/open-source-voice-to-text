#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OpenSourceVoiceToText"
APP_DIR="build/${APP_NAME}.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
cp ".build/release/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Verifying signature"
codesign -v "${APP_DIR}"

echo ""
echo "Done. Launch with:  open ${APP_DIR}"
