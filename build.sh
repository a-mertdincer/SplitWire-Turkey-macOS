#!/usr/bin/env bash
#
# SplitWire-Turkey macOS - release build script
#
# Builds a universal (Apple Silicon + Intel) SplitWire-Turkey.app with a universal ciadpi built
# from the vendored byedpi/ sources, signs it ad-hoc (inside-out), verifies it, and packages
# dist/SplitWire-Turkey-v<VERSION>.zip plus a .sha256 checksum file.
#
# Usage:
#   ./build.sh [VERSION] [--skip-zip] [--arch-native] [--clean]
#
#   VERSION        Marketing version (CFBundleShortVersionString). Default: $VERSION or 1.1.1
#   --skip-zip     Build, sign and verify the .app but do not create the release zip.
#   --arch-native  Fast development build for this Mac's architecture only (implies --skip-zip,
#                  so an arm64-only build can never be mistaken for the universal release).
#   --clean        Delete the Swift build directory and build/ before building.
#
# Environment:
#   VERSION        Same as the VERSION argument (the argument wins).
#   BUILD_NUMBER   CFBundleVersion. Default: number of git commits (git rev-list --count HEAD), or 1.
#   SCRATCH_PATH   Swift build directory. Default: .build
#   ALLOW_DIRTY    Set to 1 to package a release zip even though build inputs have uncommitted
#                  changes (the commit is then recorded as "<sha>-dirty"). Default: refuse.
#   SDKROOT        Optional SDK to build against (e.g. a macOS 26.x SDK with Command Line Tools).
#
# Output:
#   SplitWire-Turkey.app                         signed app bundle (repo root, gitignored)
#   dist/SplitWire-Turkey-v<VERSION>.zip         release artifact (gitignored)
#   dist/SplitWire-Turkey-v<VERSION>.zip.sha256  checksum ("shasum -a 256 -c" compatible)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"

APP_NAME="SplitWire-Turkey"
# Must stay identical to v1.0.0 so existing users keep their settings (UserDefaults domain).
BUNDLE_ID="com.cagritaskin.splitwire-turkey"
MIN_MACOS="13.0"
COPYRIGHT="Copyright © 2025 Çağrı Taşkın. All rights reserved."

BUILD_DIR="$ROOT/build"          # intermediate outputs (ciadpi, staged .app)
DIST_DIR="$ROOT/dist"            # release artifacts
APP_BUNDLE="$ROOT/$APP_NAME.app" # final app bundle

# --- helpers ------------------------------------------------------------------
STEP=0
STEPS=6
step()  { STEP=$((STEP + 1)); printf '\n==> [%d/%d] %s\n' "$STEP" "$STEPS" "$*"; }
info()  { printf '  %s\n' "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
die()   { printf '\n  [error] %s\n' "$*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. $2"; }

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# --- arguments ------------------------------------------------------------------
SKIP_ZIP=0
ARCH_NATIVE=0
CLEAN=0
VERSION_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-zip)    SKIP_ZIP=1 ;;
        --arch-native) ARCH_NATIVE=1; SKIP_ZIP=1 ;;
        --clean)       CLEAN=1 ;;
        -h|--help)     usage; exit 0 ;;
        -*)            die "unknown option: $1 (see ./build.sh --help)" ;;
        *)
            [[ -z "$VERSION_ARG" ]] || die "unexpected argument: $1 (see ./build.sh --help)"
            VERSION_ARG="$1" ;;
    esac
    shift
done

VERSION="${VERSION_ARG:-${VERSION:-1.1.1}}"
VERSION="${VERSION#v}"   # accept "v1.1.0"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] \
    || die "invalid VERSION '$VERSION' (expected e.g. 1.1.0)"

if [[ -z "${BUILD_NUMBER:-}" ]]; then
    BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || true)"
    [[ -n "$BUILD_NUMBER" ]] || BUILD_NUMBER=1
fi
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "invalid BUILD_NUMBER '$BUILD_NUMBER' (expected an integer)"

SCRATCH_PATH="${SCRATCH_PATH:-$ROOT/.build}"
[[ "$SCRATCH_PATH" == /* ]] || SCRATCH_PATH="$ROOT/$SCRATCH_PATH"
while [[ "$SCRATCH_PATH" == */ && "$SCRATCH_PATH" != "/" ]]; do SCRATCH_PATH="${SCRATCH_PATH%/}"; done

if [[ $ARCH_NATIVE -eq 1 ]]; then
    ARCHS="$(uname -m)"
    SWIFT_ARCH_FLAGS=()
    CIADPI_FLAGS=(--arch-native)
    BUILD_KIND="development ($(uname -m) only)"
else
    ARCHS="arm64 x86_64"
    SWIFT_ARCH_FLAGS=(--arch arm64 --arch x86_64)
    CIADPI_FLAGS=()
    BUILD_KIND="universal release (arm64 + x86_64)"
fi
if [[ $SKIP_ZIP -eq 1 ]]; then STEPS=5; fi

# --- preflight ------------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "build.sh must run on macOS"
require swift    "Install Xcode (full Xcode is recommended; see README)."
# The Command Line Tools ship the macOS 27 SDK, where SwiftUI's @State is a macro, but not the
# SwiftUIMacros compiler plugin: the build would fail with a wall of 'StateMacro' errors.
DEV_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
case "${SDKROOT:-}" in
    /*) SDK_PATH="$SDKROOT" ;;
    "") SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)" ;;
    *)  SDK_PATH="$(xcrun --sdk "$SDKROOT" --show-sdk-path 2>/dev/null || true)" ;;
esac
if [[ "$DEV_DIR" == *CommandLineTools* && ! -e "$DEV_DIR/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" ]] \
   && grep -qs 'type: "StateMacro"' "$SDK_PATH"/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/*.swiftinterface; then
    die "The Command Line Tools cannot build this app with the $(basename "$(cd "$SDK_PATH" 2>/dev/null && pwd -P || echo "$SDK_PATH")") SDK: SwiftUI's @State is a macro there and the CLT does not ship the SwiftUIMacros plugin. Install Xcode and run 'sudo xcode-select -s /Applications/Xcode.app', or build against an older SDK, e.g. SDKROOT=\$(xcrun --sdk macosx26.5 --show-sdk-path) ./build.sh"
fi
require cc       "Install the Xcode Command Line Tools (xcode-select --install)."
require lipo     "Install the Xcode Command Line Tools (xcode-select --install)."
require codesign "Install the Xcode Command Line Tools (xcode-select --install)."
require ditto    "It ships with macOS."
require plutil   "It ships with macOS."
require shasum   "It ships with macOS."
[[ -f "$ROOT/AppIcon.icns" ]] || die "AppIcon.icns not found in $ROOT"
[[ -x "$ROOT/scripts/build-ciadpi.sh" && -x "$ROOT/scripts/verify-app.sh" ]] \
    || die "scripts/build-ciadpi.sh and scripts/verify-app.sh must exist and be executable"

# A release zip must match a commit: refuse uncommitted build inputs (incl. new untracked
# sources) before the long universal build, unless explicitly allowed.
BUILD_INPUTS=(Package.swift Sources byedpi scripts build.sh AppIcon.icns)
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY_INPUTS="$(git status --porcelain -- "${BUILD_INPUTS[@]}" 2>/dev/null || true)"
if [[ -n "$DIRTY_INPUTS" ]]; then
    GIT_COMMIT="$GIT_COMMIT-dirty"
    if [[ $SKIP_ZIP -eq 0 && "${ALLOW_DIRTY:-0}" != 1 ]]; then
        printf '%s\n' "$DIRTY_INPUTS" | sed 's/^/    /' >&2
        die "refusing to package a release zip from uncommitted build inputs; commit first, or use --skip-zip / ALLOW_DIRTY=1"
    fi
    warn "building from uncommitted changes ($GIT_COMMIT)"
fi
if [[ $SKIP_ZIP -eq 0 && "$GIT_COMMIT" != *-dirty ]]; then
    TAG="$(git describe --exact-match --tags HEAD 2>/dev/null || true)"
    [[ "$TAG" == "v$VERSION" ]] || warn "HEAD is not tagged v$VERSION (tag: ${TAG:-none})"
fi
GIT_DESC="$GIT_COMMIT"

printf 'SplitWire-Turkey build\n'
info "version:    $VERSION (build $BUILD_NUMBER)"
info "kind:       $BUILD_KIND"
info "bundle id:  $BUNDLE_ID"
info "git:        $GIT_DESC"
info "toolchain:  $(swift --version 2>&1 | head -n 1)"
info "scratch:    $SCRATCH_PATH"

if [[ $CLEAN -eq 1 ]]; then
    # Only ever delete something that is clearly a SwiftPM build directory.
    if [[ -e "$SCRATCH_PATH" && ! -f "$SCRATCH_PATH/workspace-state.json" ]]; then
        die "refusing to delete SCRATCH_PATH '$SCRATCH_PATH' (not a SwiftPM build directory)"
    fi
    info "cleaning $SCRATCH_PATH and $BUILD_DIR"
    rm -rf "$SCRATCH_PATH" "$BUILD_DIR"
fi

# --- 1. Swift build -------------------------------------------------------------
step "Building Swift package ($BUILD_KIND)"
SWIFT_BUILD=(swift build -c release ${SWIFT_ARCH_FLAGS[@]+"${SWIFT_ARCH_FLAGS[@]}"} --scratch-path "$SCRATCH_PATH")
"${SWIFT_BUILD[@]}" || die "swift build failed (see the compiler output above)"
# The products directory differs between toolchains/build systems; ask SwiftPM for it.
BIN_DIR="$("${SWIFT_BUILD[@]}" --show-bin-path | tail -n 1)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
[[ -x "$EXECUTABLE" ]] || die "built executable not found at $EXECUTABLE"
EXEC_ARCHS="$(lipo -archs "$EXECUTABLE")"
for a in $ARCHS; do
    [[ " $EXEC_ARCHS " == *" $a "* ]] || die "$APP_NAME executable is missing architecture $a (has: $EXEC_ARCHS)"
done
ok "executable: $EXECUTABLE"
ok "architectures: $EXEC_ARCHS"

# --- 2. ciadpi from source ------------------------------------------------------
step "Building ciadpi from byedpi/ sources"
CIADPI_OUT="$BUILD_DIR/ciadpi/ciadpi"
rm -rf "$BUILD_DIR/ciadpi"
"$ROOT/scripts/build-ciadpi.sh" --output "$CIADPI_OUT" ${CIADPI_FLAGS[@]+"${CIADPI_FLAGS[@]}"}

# --- 3. app bundle --------------------------------------------------------------
step "Assembling $APP_NAME.app"
STAGE_APP="$BUILD_DIR/stage/$APP_NAME.app"
rm -rf "$BUILD_DIR/stage"
CONTENTS="$STAGE_APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/bin"

install -m 0755 "$EXECUTABLE" "$CONTENTS/MacOS/$APP_NAME"
install -m 0755 "$CIADPI_OUT" "$CONTENTS/Resources/bin/ciadpi"
install -m 0644 "$ROOT/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"

# SwiftPM resource bundles: only when Package.swift actually declares `resources:`.
# (An old build directory can still contain a stale bundle from v1.0.0, which shipped an
# arm64-only ciadpi as a resource - never package that.) Bundle.module looks in
# Bundle.main.resourceURL first, so declared bundles belong in Contents/Resources.
shopt -s nullglob
FOUND_BUNDLES=("$BIN_DIR"/*.bundle)
shopt -u nullglob
RESOURCE_BUNDLES=()
if grep -Eq '^[^/]*resources[[:space:]]*:' "$ROOT/Package.swift"; then
    [[ ${#FOUND_BUNDLES[@]} -gt 0 ]] || die "Package.swift declares resources but no .bundle was found in $BIN_DIR"
    for b in "${FOUND_BUNDLES[@]}"; do
        ditto "$b" "$CONTENTS/Resources/$(basename "$b")"
        RESOURCE_BUNDLES+=("$b")
        info "copied SwiftPM resource bundle $(basename "$b")"
    done
else
    for b in ${FOUND_BUNDLES[@]+"${FOUND_BUNDLES[@]}"}; do
        info "ignoring stale SwiftPM resource bundle $(basename "$b") (Package.swift declares no resources)"
    done
fi

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>tr</string>
    </array>
    <key>SWGitCommit</key>
    <string>${GIT_COMMIT}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>${COPYRIGHT}</string>
</dict>
</plist>
EOF
plutil -lint "$CONTENTS/Info.plist" | sed 's/^/  /'
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$CONTENTS/Info.plist")" == "$BUNDLE_ID" ]] \
    || die "Info.plist CFBundleIdentifier mismatch"
ok "Info.plist: $BUNDLE_ID $VERSION ($BUILD_NUMBER), macOS $MIN_MACOS+"

# --- 4. ad-hoc signing (inside-out) ---------------------------------------------
step "Signing (ad-hoc, inside-out)"
# Extended attributes (Finder info, resource forks) break code signatures.
xattr -cr "$STAGE_APP"
for b in ${RESOURCE_BUNDLES[@]+"${RESOURCE_BUNDLES[@]}"}; do
    codesign --force --sign - --timestamp=none "$CONTENTS/Resources/$(basename "$b")"
done
codesign --force --sign - --timestamp=none --identifier "$BUNDLE_ID.ciadpi" \
    "$CONTENTS/Resources/bin/ciadpi"
ok "signed Contents/Resources/bin/ciadpi"
# No hardened runtime: the signature is ad-hoc and the app drives osascript/networksetup.
codesign --force --sign - --timestamp=none "$STAGE_APP"
ok "signed $APP_NAME.app"
codesign -dv "$STAGE_APP" 2>&1 | sed 's/^/    | /'

# --- 5. verification ------------------------------------------------------------
step "Verifying the app bundle"
"$ROOT/scripts/verify-app.sh" "$STAGE_APP" \
    --archs "$ARCHS" --version "$VERSION" --build "$BUILD_NUMBER" \
    --bundle-id "$BUNDLE_ID" --min-macos "$MIN_MACOS"

rm -rf "$APP_BUNDLE"
mv "$STAGE_APP" "$APP_BUNDLE"
rmdir "$BUILD_DIR/stage" 2>/dev/null || true
ok "app bundle: $APP_BUNDLE"

# --- 6. release zip -------------------------------------------------------------
ZIP=""
if [[ $SKIP_ZIP -eq 0 ]]; then
    step "Packaging release zip"
    mkdir -p "$DIST_DIR"
    ZIP="$DIST_DIR/$APP_NAME-v$VERSION.zip"
    ZIP_NAME="$(basename "$ZIP")"
    rm -f "$ZIP" "$ZIP.sha256"
    # --norsrc (implies --noextattr/--noacl): the bundle has no resource forks, and the only
    # remaining xattr is the build machine's unremovable com.apple.provenance, which would
    # otherwise be shipped as __MACOSX/._* entries. The signature does not depend on xattrs
    # (the unzipped copy is re-verified below); permissions and symlinks are preserved.
    ( cd "$ROOT" && ditto -c -k --norsrc --keepParent "$APP_NAME.app" "$ZIP" )
    if unzip -Z1 "$ZIP" | grep '^__MACOSX/' >/dev/null; then
        die "zip unexpectedly contains __MACOSX metadata"
    fi
    ( cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256" )
    ok "created $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
    info "re-verifying the unzipped app:"
    "$ROOT/scripts/verify-app.sh" "$ZIP" \
        --archs "$ARCHS" --version "$VERSION" --build "$BUILD_NUMBER" \
        --bundle-id "$BUNDLE_ID" --min-macos "$MIN_MACOS"
fi

# --- summary --------------------------------------------------------------------
printf '\nBuild complete: %s %s (build %s), %s\n' "$APP_NAME" "$VERSION" "$BUILD_NUMBER" "$BUILD_KIND"
info "app:    $APP_BUNDLE"
if [[ -n "$ZIP" ]]; then
    info "zip:    $ZIP"
    info "sha256: $(awk '{print $1}' "$ZIP.sha256")"
fi
cat <<'EOF'

  Run:      open SplitWire-Turkey.app
  Install:  ditto SplitWire-Turkey.app /Applications/SplitWire-Turkey.app

  The app is signed ad-hoc (no Apple Developer ID), so on first launch of a downloaded copy
  macOS says it cannot verify the developer. Users can allow it via
  System Settings > Privacy & Security > "Open Anyway", or with:
    xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app
EOF
