#!/usr/bin/env bash
#
# Verifies a SplitWire-Turkey.app bundle (or a release .zip containing one):
#   - code signature is valid (codesign --verify --deep --strict), resources sealed, Info.plist bound
#   - main executable and bundled ciadpi contain the expected architectures and run on macOS 13+
#   - bundled ciadpi starts (`--version`)
#   - Info.plist is valid and has the expected bundle identifier / version
#   - for a .zip: the adjacent .sha256 file matches (if present)
#
# Usage:
#   scripts/verify-app.sh PATH [--archs "arm64 x86_64"] [--version X.Y.Z] [--build N]
#                              [--bundle-id ID] [--min-macos 13.0]
#
#   PATH is a .app bundle or a .zip produced by build.sh.

set -euo pipefail

APP_NAME="SplitWire-Turkey"
EXPECTED_ARCHS="arm64 x86_64"
EXPECTED_VERSION=""
EXPECTED_BUILD=""
EXPECTED_BUNDLE_ID="com.cagritaskin.splitwire-turkey"
MIN_MACOS="13.0"
TARGET=""

info()  { printf '  %s\n' "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
die()   { printf '  [error] %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archs)      [[ $# -ge 2 ]] || die "--archs needs a value";      EXPECTED_ARCHS="$2"; shift 2 ;;
        --version)    [[ $# -ge 2 ]] || die "--version needs a value";    EXPECTED_VERSION="$2"; shift 2 ;;
        --build)      [[ $# -ge 2 ]] || die "--build needs a value";      EXPECTED_BUILD="$2"; shift 2 ;;
        --bundle-id)  [[ $# -ge 2 ]] || die "--bundle-id needs a value";  EXPECTED_BUNDLE_ID="$2"; shift 2 ;;
        --min-macos)  [[ $# -ge 2 ]] || die "--min-macos needs a value";  MIN_MACOS="$2"; shift 2 ;;
        -h|--help)    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)           die "unknown option: $1 (see --help)" ;;
        *)            [[ -z "$TARGET" ]] || die "only one PATH may be given"; TARGET="$1"; shift ;;
    esac
done
[[ -n "$TARGET" ]] || die "usage: scripts/verify-app.sh PATH.app|PATH.zip [options] (see --help)"
[[ -e "$TARGET" ]] || die "not found: $TARGET"

# Returns 0 if version $1 > version $2 (numeric, dot separated).
version_gt() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        na = split(a, x, "."); nb = split(b, y, ".");
        n = (na > nb) ? na : nb;
        for (i = 1; i <= n; i++) { xi = x[i] + 0; yi = y[i] + 0;
            if (xi > yi) exit 0; if (xi < yi) exit 1; }
        exit 1 }'
}

check_macho() {
    local label="$1" file="$2"
    [[ -f "$file" ]] || die "$label not found: $file"
    [[ -x "$file" ]] || die "$label is not executable: $file"
    local archs; archs="$(lipo -archs "$file")"
    local a
    for a in $EXPECTED_ARCHS; do
        [[ " $archs " == *" $a "* ]] || die "$label is missing architecture $a (has: $archs)"
    done
    ok "$label architectures: $archs"
    if command -v vtool >/dev/null 2>&1; then
        local minos
        for minos in $(vtool -show-build "$file" 2>/dev/null | awk '$1 == "minos" { print $2 }' | sort -u); do
            if version_gt "$minos" "$MIN_MACOS"; then
                die "$label requires macOS $minos but the app promises macOS $MIN_MACOS+"
            fi
        done
    fi
}

WORK_DIR=""
cleanup() { [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; return 0; }
trap cleanup EXIT

APP="$TARGET"
if [[ "$TARGET" == *.zip ]]; then
    if [[ -f "$TARGET.sha256" ]]; then
        ( cd "$(dirname "$TARGET")" && shasum -a 256 -c "$(basename "$TARGET").sha256" >/dev/null ) \
            || die "SHA-256 mismatch for $TARGET"
        ok "SHA-256 matches $(basename "$TARGET").sha256"
    else
        warn "no $(basename "$TARGET").sha256 next to the zip - checksum not verified"
    fi
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/splitwire-verify.XXXXXX")"
    ditto -x -k "$TARGET" "$WORK_DIR" || die "could not extract $TARGET"
    APP="$WORK_DIR/$APP_NAME.app"
    [[ -d "$APP" ]] || die "$APP_NAME.app not found at the top level of $TARGET"
    ok "extracted $(basename "$TARGET")"
fi
[[ -d "$APP" ]] || die "not an app bundle: $APP"

CONTENTS="$APP/Contents"
PLIST="$CONTENTS/Info.plist"
MAIN_EXEC="$CONTENTS/MacOS/$APP_NAME"
CIADPI="$CONTENTS/Resources/bin/ciadpi"

# --- Info.plist ---------------------------------------------------------------
plutil -lint -s "$PLIST" || die "Info.plist is not valid"
plist_get() { plutil -extract "$1" raw -o - "$PLIST" 2>/dev/null || true; }
BUNDLE_ID="$(plist_get CFBundleIdentifier)"
SHORT_VERSION="$(plist_get CFBundleShortVersionString)"
BUILD_NUMBER="$(plist_get CFBundleVersion)"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || die "CFBundleIdentifier is '$BUNDLE_ID', expected '$EXPECTED_BUNDLE_ID'"
[[ "$(plist_get CFBundleExecutable)" == "$APP_NAME" ]] || die "CFBundleExecutable is not $APP_NAME"
[[ "$(plist_get LSMinimumSystemVersion)" == "$MIN_MACOS" ]] || die "LSMinimumSystemVersion is not $MIN_MACOS"
plutil -extract CFBundleLocalizations json -o - "$PLIST" 2>/dev/null | grep -q '"tr"' \
    || die "CFBundleLocalizations must list tr (system menus/panels would stay English, #8)"
[[ -z "$EXPECTED_VERSION" || "$SHORT_VERSION" == "$EXPECTED_VERSION" ]] \
    || die "CFBundleShortVersionString is '$SHORT_VERSION', expected '$EXPECTED_VERSION'"
[[ -z "$EXPECTED_BUILD" || "$BUILD_NUMBER" == "$EXPECTED_BUILD" ]] \
    || die "CFBundleVersion is '$BUILD_NUMBER', expected '$EXPECTED_BUILD'"
ok "Info.plist: $BUNDLE_ID $SHORT_VERSION ($BUILD_NUMBER)"

# --- binaries -------------------------------------------------------------------
check_macho "main executable" "$MAIN_EXEC"
check_macho "ciadpi" "$CIADPI"
CIADPI_VERSION="$("$CIADPI" --version 2>&1 | head -n 1 | tr -d '[:space:]')" || true
[[ -n "$CIADPI_VERSION" ]] || die "bundled ciadpi did not print a version"
ok "bundled ciadpi --version: $CIADPI_VERSION"

# --- code signature -------------------------------------------------------------
if ! codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    | /'; then
    die "codesign verification failed"
fi
codesign --verify --strict "$CIADPI" || die "ciadpi signature is invalid"

SIGN_INFO="$(codesign -dv "$APP" 2>&1)"
grep -q '^Sealed Resources version=' <<<"$SIGN_INFO" || die "resources are not sealed (Sealed Resources=none)"
grep -q '^Info.plist entries=' <<<"$SIGN_INFO" || die "Info.plist is not bound to the signature"
ok "signature valid: $(grep -E '^Signature=' <<<"$SIGN_INFO" | head -n 1), $(grep -E '^Sealed Resources' <<<"$SIGN_INFO" | head -n 1), $(grep -E '^Info.plist' <<<"$SIGN_INFO" | head -n 1)"

ok "$APP_NAME.app verified"
