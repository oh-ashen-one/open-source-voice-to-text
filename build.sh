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

# Sign with a stable identity so macOS TCC permissions (Microphone,
# Accessibility) survive rebuilds. Ad-hoc signatures change hash on every
# build, which makes macOS re-prompt for permissions each time.
IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)"
if [ -n "${IDENTITY}" ]; then
    echo "==> Code signing with: ${IDENTITY}"
    codesign --force --deep --sign "${IDENTITY}" "${APP_DIR}"
else
    echo "==> WARNING: no Apple Development identity found; falling back to ad-hoc signing."
    echo "    Permissions will be re-requested on every rebuild."
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Verifying signature"
codesign -v "${APP_DIR}"

echo ""
echo "Done. Launch with:  open ${APP_DIR}"
