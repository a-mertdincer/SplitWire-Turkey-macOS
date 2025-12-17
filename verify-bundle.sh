#!/bin/bash

# Bundle Verification Script for SplitWire-Turkey
# This script verifies that the app bundle is correctly built and signed

APP_BUNDLE="SplitWire-Turkey.app"

echo "🔍 Verifying bundle: ${APP_BUNDLE}"
echo ""

# Check if bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ ERROR: ${APP_BUNDLE} not found!"
    exit 1
fi

echo "✅ Bundle exists"

# Check bundle structure
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

if [ ! -d "${CONTENTS}" ]; then
    echo "❌ ERROR: Contents directory missing!"
    exit 1
fi

if [ ! -d "${MACOS}" ]; then
    echo "❌ ERROR: MacOS directory missing!"
    exit 1
fi

if [ ! -d "${RESOURCES}" ]; then
    echo "❌ ERROR: Resources directory missing!"
    exit 1
fi

echo "✅ Bundle structure is valid"
echo ""

# Check Info.plist
if [ ! -f "${CONTENTS}/Info.plist" ]; then
    echo "❌ ERROR: Info.plist not found!"
    exit 1
fi
echo "✅ Info.plist exists"

# Check PkgInfo
if [ ! -f "${CONTENTS}/PkgInfo" ]; then
    echo "❌ ERROR: PkgInfo not found!"
    exit 1
fi
echo "✅ PkgInfo exists"

# Check executable
if [ ! -f "${MACOS}/SplitWire-Turkey" ]; then
    echo "❌ ERROR: Executable not found!"
    exit 1
fi

if [ ! -x "${MACOS}/SplitWire-Turkey" ]; then
    echo "⚠️  WARNING: Executable is not marked as executable, fixing..."
    chmod +x "${MACOS}/SplitWire-Turkey"
fi
echo "✅ Executable exists and is executable"

# Check architecture of executable
echo ""
echo "📋 Executable Info:"
file "${MACOS}/SplitWire-Turkey" | grep -o "arm64\|x86_64\|universal"
lipo -info "${MACOS}/SplitWire-Turkey" 2>/dev/null || echo "   (Single architecture binary)"

# Check for ciadpi binary
if [ -f "${RESOURCES}/bin/ciadpi" ]; then
    if [ ! -x "${RESOURCES}/bin/ciadpi" ]; then
        echo "⚠️  WARNING: ciadpi is not executable, fixing..."
        chmod +x "${RESOURCES}/bin/ciadpi"
    fi
    echo "✅ ByeDPI binary (ciadpi) found and executable"
    
    echo "   Architecture:"
    file "${RESOURCES}/bin/ciadpi" | grep -o "arm64\|x86_64\|universal"
else
    echo "⚠️  WARNING: ByeDPI binary (ciadpi) not found!"
    echo "   The app may not work correctly without it"
fi

# Check for App Icon
if [ -f "${RESOURCES}/AppIcon.icns" ]; then
    echo "✅ App icon found"
else
    echo "⚠️  WARNING: App icon (AppIcon.icns) not found!"
fi

echo ""
echo "📄 Bundle Contents:"
find "${APP_BUNDLE}" -type f | sed 's|^|   |'

echo ""
echo "🔐 Checking code signature..."
if codesign -v "${APP_BUNDLE}" 2>&1 | grep -q "valid on disk"; then
    echo "✅ Bundle is properly signed"
else
    echo "⚠️  Bundle signature status:"
    codesign -v "${APP_BUNDLE}" 2>&1 | sed 's|^|   |'
fi

echo ""
echo "✅ Verification complete!"
echo ""
echo "To run the application:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "If you get a security warning, you can allow it with:"
echo "  xattr -d com.apple.quarantine ${APP_BUNDLE}"
echo "  open ${APP_BUNDLE}"
