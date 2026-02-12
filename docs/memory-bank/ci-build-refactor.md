# CI Build Refactor: Build Outside Container with Native ARM64

## Status

Not started. This is a follow-up to the modernization effort completed in commits `387a4e9` through
`8066021`.

## Problem

The current CI builds Zandronum inside a Docker multi-stage build. The arm64 image is built via QEMU
emulation on an amd64 runner, which takes ~25 minutes per variant. A full official build (both
arches) takes ~52 minutes. This also makes build caching (ccache) impractical because the build
context is ephemeral and opaque to the CI system.

## Proposed Architecture

Three-layer design: a core build script, a local dev wrapper, and CI workflow. All share one
Dockerfile (runtime-only) and one build script.

### Script layers

**`build.sh`** -- core build logic. Portable, no tool management, no path opinions. Takes everything
via env vars. Used by CI directly and by the local wrapper.

Required env vars:

- `REPO_URL`: Mercurial repository URL
- `REPO_TAG`: Tag or commit hash to clone
- `VARIANT`: `official` or `tspg` (selects variant-specific patches)
- `BUILD_DIR`: Where to clone and compile (default: `build`)
- `DIST_DIR`: Where to place final artifacts (default: `dist`)

Steps:

1. `hg clone "$REPO_URL" -r "$REPO_TAG" "$BUILD_DIR/zandronum"`
2. Apply patches: `docker-files/patches/common/*.patch` then
   `docker-files/patches/$VARIANT/*.patch`
3. cmake configure + build with ccache if available
4. Copy `zandronum-server` and `zandronum.pk3` to `$DIST_DIR/`

**`local-build.sh`** -- local dev convenience wrapper. Ensures mise tools are installed, sets sane
defaults, calls `build.sh`.

```bash
#!/usr/bin/env bash
set -exu

mise install

export BUILD_DIR="./build/${VARIANT:?Set VARIANT=official or VARIANT=tspg}"
export DIST_DIR="./dist/${VARIANT}"

./build.sh

echo "Build complete. Run 'docker compose build ${VARIANT}' to package."
```

Add `build/` and `dist/` to `.gitignore`.

### Dockerfile

Single Dockerfile, runtime-only. Replaces the current multi-stage Dockerfile entirely.

```dockerfile
FROM ubuntu:22.04
ARG DIST_DIR=dist
COPY ${DIST_DIR}/zandronum-server ${DIST_DIR}/zandronum.pk3 /usr/local/games/zandronum/
COPY docker-files/zandronum-server.sh /usr/local/bin/zandronum-server
COPY docker-files/GeoLite2-Country.mmdb /usr/local/games/zandronum/GeoIP.dat
COPY docker-files/entrypoint.sh /entrypoint.sh
RUN true \
    && apt-get update -qq \
    && apt-get install -qq --no-install-recommends \
        tini \
        libssl3 \
        # libsdl1.2-compat-shim places libSDL-1.2.so.0 on the standard library path
        libsdl1.2-compat-shim \
        libopus0 \
        gosu \
        > /dev/null \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /entrypoint.sh /usr/local/bin/zandronum-server
ENV ZANDRONUM_UID= \
    ZANDRONUM_GID=
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
```

### docker-compose.yml

Services no longer pass repo/tag/variant as Docker build args. They just need `DIST_DIR` to point
at the correct artifacts directory:

```yaml
services:
  official:
    image: rcdailey/zandronum-server:official-local
    build:
      context: .
      args:
        - DIST_DIR=dist/official

  tspg:
    image: rcdailey/zandronum-server:tspg-local
    build:
      context: .
      args:
        - DIST_DIR=dist/tspg
```

### CI workflow structure

```yaml
jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        variant: [official, tspg]
        include:
          - variant: official
            repo_url: https://foss.heptapod.net/zandronum/zandronum-stable
            repo_tag: ZA_3.2.1
          - variant: tspg
            repo_url: http://hg.code.sf.net/p/zandronum-tspg/code
            repo_tag: TSPGv32
        arch:
          - { name: amd64, runner: ubuntu-latest }
          - { name: arm64, runner: ubuntu-24.04-arm }
    runs-on: ${{ matrix.arch.runner }}
    steps:
      - checkout
      - apt-get install build deps
      - restore ccache (actions/cache, keyed on variant + repo_tag + arch)
      - REPO_URL=... REPO_TAG=... VARIANT=... ./build.sh
      - save ccache
      - upload artifacts (zandronum-server, zandronum.pk3)

  package:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - checkout
      - download artifacts for both arches
      - docker/setup-buildx-action
      - for each variant + arch: build single-platform image from Dockerfile
      - docker manifest create (combine into multi-arch tags)
      - push
      - update Docker Hub description
```

### Key benefits

- Native arm64 builds (no QEMU; probably 5-10x faster for that arch)
- ccache via `actions/cache` (incremental rebuilds for patch version bumps)
- Single build script shared between CI and local dev
- Single Dockerfile (no multi-stage, no duplication)
- Both variants can be built locally without clobbering each other (separate dist directories)
- Total CI time expected to drop from ~52 min to ~10-15 min

## Implementation Order

1. Write `build.sh` with the core compilation logic extracted from the Dockerfile
2. Write `local-build.sh` wrapper with mise integration
3. Rewrite Dockerfile to runtime-only, accepting `DIST_DIR` arg
4. Update `docker-compose.yml` to use `DIST_DIR` per variant
5. Test locally: `VARIANT=official ./local-build.sh && docker compose build official`
6. Rewrite `.github/workflows/build.yml` with the matrix/package job structure
7. Update AGENTS.md and README.md with new build instructions
8. Add `build/` and `dist/` to `.gitignore`

## Resolved Questions (from previous session)

- TSPG is fixed: moved to SourceForge, TSPGv32 with a compile patch
- `zandronum-server.sh` INSTALL_DIR: hardcode the path (`/usr/local/games/zandronum`) instead of
  the sed replacement. The path is a constant in this project.
- Local dev: single Dockerfile approach (no Dockerfile.ci). The build script handles compilation
  outside Docker for both local and CI.

## Open Questions

- Verify `ubuntu-24.04-arm` runner availability for this repo (public, should be fine)
- ccache key strategy: `variant + repo_tag + arch` seems right. Maybe include a hash of cmake
  flags to bust cache on flag changes.
- The `package` job needs to handle 2 variants x 2 arches = 4 artifact combinations. Decide
  whether to use a nested matrix or sequential steps.
- mise.toml: decide which tools to manage via mise for local builds (mercurial is already there;
  cmake and ninja could be added)
- GHA cache limit: 10 GB per repo. ccache stores should be well within this.

## Build Dependencies Reference

- Build: mercurial, g++, cmake, ninja-build, libssl-dev, libsdl1.2-compat-dev, libopus-dev, patch
- Runtime: tini, libssl3, libsdl1.2-compat-shim, libopus0, gosu
- Official repo: `https://foss.heptapod.net/zandronum/zandronum-stable` tag `ZA_3.2.1`
- TSPG repo: `http://hg.code.sf.net/p/zandronum-tspg/code` tag `TSPGv32`
- cmake flags: `-G Ninja -W no-dev -D CMAKE_BUILD_TYPE=Release -D SERVERONLY=1
  -D CMAKE_C_FLAGS="-w" -D CMAKE_CXX_FLAGS="-w"`
