#!/bin/bash

# SplitWire-Turkey macOS Build Script
# This script builds the macOS application

set -e

echo "🔨 Building SplitWire-Turkey for macOS..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build
rm -rf SplitWire-Turkey.app

# Build the application
echo "📦 Building Swift package..."
swift build -c release

# Create app bundle structure
echo "🎁 Creating application bundle..."
APP_NAME="SplitWire-Turkey"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable
echo "📋 Copying executable..."
cp ".build/release/${APP_NAME}" "${MACOS}/"

# Copy ByeDPI binary
echo "📋 Copying ByeDPI binary..."
mkdir -p "${RESOURCES}/bin"
if [ -f "byedpi/ciadpi" ]; then
    cp "byedpi/ciadpi" "${RESOURCES}/bin/"
    chmod +x "${RESOURCES}/bin/ciadpi"
    echo "  ✓ ByeDPI (ciadpi) copied"
else
    echo "  ⚠ Warning: byedpi/ciadpi not found, skipping..."
fi

# Copy App Icon
echo "📋 Copying application icon..."
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES}/"
    echo "  ✓ App icon copied"
else
    echo "  ⚠ Warning: AppIcon.icns not found, skipping..."
fi

# Create Info.plist
echo "📄 Creating Info.plist..."
cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.cagritaskn.splitwire-turkey</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Çağrı Taşkın. All rights reserved.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "${CONTENTS}/PkgInfo"

echo "✅ Build complete!"
echo "📱 Application bundle created: ${APP_BUNDLE}"
echo ""
echo "To run the application:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install to Applications folder:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
