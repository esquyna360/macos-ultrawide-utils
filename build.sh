#!/bin/bash
set -e

APP_NAME="SpaceFlow"
APP_BUNDLE="${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
PLIST_FILE="${APP_BUNDLE}/Contents/Info.plist"

echo "========================================="
echo "Building ${APP_NAME} for macOS arm64..."
echo "========================================="

# 1. Clean previous build if it exists
if [ -d "${APP_BUNDLE}" ]; then
    echo "Cleaning previous app bundle..."
    rm -rf "${APP_BUNDLE}"
fi

# 2. Create the App Bundle directory structure
echo "Creating bundle directories..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Compile all Swift source files together
echo "Compiling Swift source files..."
swiftc -O \
    -sdk "$(xcrun --show-sdk-path)" \
    -o "${MACOS_DIR}/${APP_NAME}" \
    src/Core/SpaceEngine.swift \
    src/Core/GestureMonitor.swift \
    src/Core/SpaceAutomator.swift \
    src/Core/HotZoneState.swift \
    src/Core/FloatingBarState.swift \
    src/UI/PermissionView.swift \
    src/UI/FloatingBarView.swift \
    src/UI/FloatingBarWindow.swift \
    src/UI/SettingsView.swift \
    src/UI/SettingsWindow.swift \
    src/UI/HotZoneWindows.swift \
    src/main.swift

# 4. Generate the Info.plist configuration
echo "Generating Info.plist..."
cat <<EOF > "${PLIST_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.bruno.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>O SpaceFlow precisa de acesso à Acessibilidade para alternar de forma rápida e prática entre seus desktops/spaces.</string>
</dict>
</plist>
EOF

# 5. Codesign the app bundle
if security find-certificate -c "SpaceFlow Local Signing" >/dev/null 2>&1; then
    echo "Signing the app bundle with 'SpaceFlow Local Signing' certificate for persistent accessibility permissions..."
    codesign --force --deep --sign "SpaceFlow Local Signing" "${APP_BUNDLE}"
else
    echo "WARNING: 'SpaceFlow Local Signing' certificate not found in keychain. Falling back to ad-hoc signing..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "Removing quarantine attributes to bypass Gatekeeper..."
xattr -cr "${APP_BUNDLE}" || true

echo "========================================="
echo "SUCCESS: ${APP_BUNDLE} created and signed successfully!"
echo "You can double click or run: open ${APP_BUNDLE}"
echo "========================================="
