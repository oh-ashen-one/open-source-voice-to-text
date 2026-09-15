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
# Use the certificate SHA-1 (unique) rather than the name, which can be
# ambiguous when multiple Apple Development certs exist in the keychain.
IDENTITY_HASH="$(security find-identity -v -p codesigning | grep 'Apple Development:' | head -1 | awk '{print $2}')"
if [ -n "${IDENTITY_HASH}" ]; then
    echo "==> Code signing with Apple Development identity ${IDENTITY_HASH}"
    codesign --force --deep --sign "${IDENTITY_HASH}" "${APP_DIR}"
else
    echo "==> WARNING: no Apple Development identity found; falling back to ad-hoc signing."
    echo "    Permissions will be re-requested on every rebuild."
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Verifying signature"
codesign -v "${APP_DIR}"

echo ""
echo "Done. Launch with:  open ${APP_DIR}"
