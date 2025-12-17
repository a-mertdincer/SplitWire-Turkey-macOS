#!/bin/bash

# SplitWire-Turkey macOS Build Script
# This script builds the macOS application for ARM64 (M1/M2/M3/M4 Macs)

set -e

echo "🔨 Building SplitWire-Turkey for macOS..."
echo "📊 System Info:"
echo "   Architecture: $(uname -m)"
echo "   macOS Version: $(sw_vers -productVersion)"
echo ""

# Check for Apple Silicon (ARM64)
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "⚠️  WARNING: You are not on Apple Silicon (ARM64). This build is optimized for M1/M2/M3/M4 Macs."
    echo "   Current architecture: $ARCH"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build
rm -rf SplitWire-Turkey.app

# Build the application
echo "📦 Building Swift package..."
swift build -c release --arch arm64 2>&1 | tee build.log

# Check for build errors
if [ $? -ne 0 ]; then
    echo "❌ Build failed! Check build.log for details"
    exit 1
fi

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
# Find the built executable - it might be in different locations depending on Swift version
BUILT_EXEC=""
if [ -f ".build/release/${APP_NAME}" ]; then
    BUILT_EXEC=".build/release/${APP_NAME}"
elif [ -f ".build/arm64-apple-macosx/release/${APP_NAME}" ]; then
    BUILT_EXEC=".build/arm64-apple-macosx/release/${APP_NAME}"
elif [ -f ".build/debug/${APP_NAME}" ]; then
    BUILT_EXEC=".build/debug/${APP_NAME}"
else
    echo "❌ ERROR: Could not find built executable!"
    exit 1
fi

cp "${BUILT_EXEC}" "${MACOS}/"
chmod +x "${MACOS}/${APP_NAME}"
echo "  ✓ Executable copied from: ${BUILT_EXEC}"

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
elif [ -d "AppIcon.iconset" ]; then
    # Convert iconset to icns if needed
    iconutil -c icns AppIcon.iconset -o "${RESOURCES}/AppIcon.icns"
    echo "  ✓ App icon converted and copied"
else
    echo "  ⚠ Warning: AppIcon files not found, skipping..."
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

# Sign the executable for M1/M2/M3/M4 Macs (Ad-hoc signing for development)
echo "🔐 Signing application for macOS..."
codesign --force --deep --sign - "${MACOS}/${APP_NAME}" 2>/dev/null || echo "⚠ Warning: Signing may have failed"

# Verify the executable is executable
chmod +x "${MACOS}/${APP_NAME}"
chmod +x "${RESOURCES}/bin/ciadpi" 2>/dev/null || echo "⚠ Warning: ciadpi not found or not executable"

# Verify bundle structure
echo ""
echo "📋 Verifying bundle structure..."
if [ ! -f "${CONTENTS}/Info.plist" ]; then
    echo "❌ ERROR: Info.plist not found!"
    exit 1
fi

if [ ! -f "${MACOS}/${APP_NAME}" ]; then
    echo "❌ ERROR: Executable not found!"
    exit 1
fi

if [ ! -f "${RESOURCES}/bin/ciadpi" ]; then
    echo "⚠ Warning: ciadpi binary not found in bundle!"
fi

echo "✅ Build complete!"
echo "📱 Application bundle created: ${APP_BUNDLE}"
echo ""
echo "To run the application:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install to Applications folder:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "To verify bundle integrity:"
echo "  codesign -v ${APP_BUNDLE}"
