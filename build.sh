#!/usr/bin/env bash
set -exu

# Core build script for Zandronum server.
# Takes everything via env vars. Used by CI directly.
#
# Required:
#   REPO_URL   Mercurial repository URL
#   REPO_TAG   Tag or commit hash to clone
#   VARIANT    "official" or "tspg" (selects variant-specific patches)
#
# Optional:
#   BUILD_DIR  Where to clone and compile (default: build)
#   DIST_DIR   Where to place final artifacts (default: dist)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${REPO_URL:?Set REPO_URL to the Mercurial repository URL}"
: "${REPO_TAG:?Set REPO_TAG to the tag or commit hash}"
: "${VARIANT:?Set VARIANT to official or tspg}"

BUILD_DIR="${BUILD_DIR:-build}"
DIST_DIR="${DIST_DIR:-dist}"

SRC_DIR="$BUILD_DIR/zandronum"

# Clone the repository
if [[ ! -d "$SRC_DIR" ]]; then
    hg clone "$REPO_URL" -r "$REPO_TAG" "$SRC_DIR"
fi

# Apply patches: common first, then variant-specific
shopt -s nullglob
for p in "$SCRIPT_DIR/docker-files/patches/common/"*.patch "$SCRIPT_DIR/docker-files/patches/$VARIANT/"*.patch; do
    patch -d "$SRC_DIR" -p1 < "$p"
done
shopt -u nullglob

# Configure cmake flags
CMAKE_ARGS=(
    -G Ninja
    -W no-dev
    -D CMAKE_BUILD_TYPE=Release
    -D SERVERONLY=1
    -D "CMAKE_C_FLAGS=-w"
    -D "CMAKE_CXX_FLAGS=-w"
)

if command -v ccache &>/dev/null; then
    CMAKE_ARGS+=(
        -D CMAKE_C_COMPILER_LAUNCHER=ccache
        -D CMAKE_CXX_COMPILER_LAUNCHER=ccache
    )
fi

# Build
cmake "${CMAKE_ARGS[@]}" -S "$SRC_DIR" -B "$SRC_DIR"
cmake --build "$SRC_DIR"

# Stage artifacts
mkdir -p "$DIST_DIR"
cp "$SRC_DIR/zandronum-server" "$SRC_DIR/zandronum.pk3" "$DIST_DIR/"
