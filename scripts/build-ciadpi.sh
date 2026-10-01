#!/usr/bin/env bash
#
# Builds ByeDPI's `ciadpi` from the vendored sources in byedpi/.
#
# - Universal (arm64 + x86_64) by default, macOS 13.0+.
# - Source list is read from byedpi/Makefile (SRC = ...); Windows-only files are never compiled.
# - Object files never land in byedpi/: everything is compiled and linked in one cc call
#   from a temporary directory.
# - The result is verified (architectures + `ciadpi --version` == VERSION in byedpi/main.c).
#
# Usage:
#   scripts/build-ciadpi.sh [--output PATH] [--arch-native]
#
#   --output PATH   Where to write the binary (default: byedpi/ciadpi, which is gitignored and is
#                   the development fallback used by `swift run` / `swift test`).
#   --arch-native   Build only for this Mac's architecture (faster, for development).
#
# Environment:
#   CC                  C compiler (default: cc)
#   MACOSX_MIN_VERSION  Deployment target (default: 13.0)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC_DIR="$ROOT/byedpi"
OUTPUT="$SRC_DIR/ciadpi"
ARCH_NATIVE=0
CC="${CC:-cc}"
MIN_MACOS="${MACOSX_MIN_VERSION:-13.0}"

info()  { printf '  %s\n' "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
die()   { printf '  [error] %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ $# -ge 2 ]] || die "--output requires a path"
            OUTPUT="$2"; shift 2 ;;
        --arch-native)
            ARCH_NATIVE=1; shift ;;
        -h|--help)
            sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            die "unknown argument: $1 (see --help)" ;;
    esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "this script must run on macOS"
command -v "$CC" >/dev/null 2>&1 || die "C compiler '$CC' not found (install Xcode Command Line Tools: xcode-select --install)"
command -v lipo >/dev/null 2>&1 || die "lipo not found (install Xcode Command Line Tools)"
[[ -f "$SRC_DIR/Makefile" && -f "$SRC_DIR/main.c" ]] || die "byedpi sources not found in $SRC_DIR"

if [[ $ARCH_NATIVE -eq 1 ]]; then
    ARCHS=("$(uname -m)")
else
    ARCHS=(arm64 x86_64)
fi

# Expected version, e.g. `#define VERSION "17.3"` in main.c
EXPECTED_VERSION="$(sed -n 's/^#define[[:space:]]\{1,\}VERSION[[:space:]]\{1,\}"\([^"]*\)".*/\1/p' "$SRC_DIR/main.c" | head -n 1)"
[[ -n "$EXPECTED_VERSION" ]] || die "could not read VERSION from byedpi/main.c"

# Source list from the Makefile (portable part only; WIN_SRC is never used on macOS).
SRC_LINE="$(sed -n 's/^SRC[[:space:]]*=[[:space:]]*//p' "$SRC_DIR/Makefile" | head -n 1)"
[[ -n "$SRC_LINE" ]] || die "could not read SRC from byedpi/Makefile"
SOURCES=()
for src in $SRC_LINE; do
    case "$src" in
        win_*|*windows*) continue ;;
    esac
    [[ -f "$SRC_DIR/$src" ]] || die "source file listed in Makefile is missing: byedpi/$src"
    SOURCES+=("$SRC_DIR/$src")
done
[[ ${#SOURCES[@]} -gt 0 ]] || die "no sources to compile"

# Same flags as byedpi/Makefile (CPPFLAGS + CFLAGS) plus macOS arch/deployment target.
ARCH_FLAGS=()
for a in "${ARCHS[@]}"; do ARCH_FLAGS+=(-arch "$a"); done
CFLAGS_ALL=(
    "${ARCH_FLAGS[@]}"
    "-mmacosx-version-min=$MIN_MACOS"
    -D_DEFAULT_SOURCE
    -I "$SRC_DIR"
    -std=c99 -O2
    -Wall -Wno-unused -Wextra -Wno-unused-parameter -pedantic
)

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ciadpi-build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

info "ciadpi $EXPECTED_VERSION: compiling ${#SOURCES[@]} files for ${ARCHS[*]} (macOS $MIN_MACOS+)"
# Compile + link in one step from WORK_DIR so no .o files are written into byedpi/.
(
    cd "$WORK_DIR"
    "$CC" "${CFLAGS_ALL[@]}" "${SOURCES[@]}" -o "$WORK_DIR/ciadpi" 2>&1 | sed 's/^/    | /'
    exit "${PIPESTATUS[0]}"
) || die "ciadpi compilation failed"

# --- verification -----------------------------------------------------------
BUILT_ARCHS="$(lipo -archs "$WORK_DIR/ciadpi")"
for a in "${ARCHS[@]}"; do
    [[ " $BUILT_ARCHS " == *" $a "* ]] || die "ciadpi is missing architecture $a (has: $BUILT_ARCHS)"
done
ok "architectures: $BUILT_ARCHS"

NATIVE_ARCH="$(uname -m)"
VERSION_OUT="$("$WORK_DIR/ciadpi" --version 2>&1 | head -n 1 | tr -d '[:space:]')" || true
[[ "$VERSION_OUT" == "$EXPECTED_VERSION" ]] \
    || die "ciadpi --version printed '$VERSION_OUT', expected '$EXPECTED_VERSION'"
ok "ciadpi --version ($NATIVE_ARCH): $VERSION_OUT"

# Also run the non-native slice when possible (Rosetta 2 on Apple Silicon).
if [[ $ARCH_NATIVE -eq 0 && "$NATIVE_ARCH" == "arm64" ]]; then
    if X86_OUT="$(arch -x86_64 "$WORK_DIR/ciadpi" --version 2>/dev/null | head -n 1 | tr -d '[:space:]')" && [[ -n "$X86_OUT" ]]; then
        [[ "$X86_OUT" == "$EXPECTED_VERSION" ]] || die "x86_64 slice printed '$X86_OUT', expected '$EXPECTED_VERSION'"
        ok "ciadpi --version (x86_64 via Rosetta): $X86_OUT"
    else
        warn "could not run the x86_64 slice (Rosetta 2 not installed?) - skipped runtime check"
    fi
fi

mkdir -p "$(dirname "$OUTPUT")"
install -m 0755 "$WORK_DIR/ciadpi" "$OUTPUT"
ok "ciadpi written to $OUTPUT"
