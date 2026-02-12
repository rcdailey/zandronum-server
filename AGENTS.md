# AGENTS.md

## Project Overview

Docker packaging project for Zandronum game servers. Builds and publishes multi-arch Docker images
(amd64/arm64) for both official Zandronum and TSPG fork to Docker Hub as
`rcdailey/zandronum-server`.

No application source code lives here; the repo contains a Dockerfile, shell scripts, CI config,
example configs, and documentation.

## Project Structure

```txt
Dockerfile                              # Multi-stage build: compile Zandronum + runtime image
README.md                               # User-facing documentation
docker-compose.yml                      # Local dev builds for both variants
docker-files/entrypoint.sh              # Container entrypoint (user/group setup, process launch)
docker-files/zandronum-server.sh        # Wrapper script setting working directory for binary
docker-files/patches/                   # Patch files applied during build (*.patch)
docker-files/GeoLite2-Country.mmdb      # GeoIP database bundled into image
examples/multiple-servers/              # Example multi-server Docker Compose setup
.github/workflows/build.yml            # CI: build + push to Docker Hub on master
```

## Build Commands

```bash
# Build both image variants locally (official + TSPG)
docker compose build

# Build only the official variant
docker compose build official

# Build only the TSPG variant
docker compose build tspg

# Build with plain Docker (official variant)
docker build \
    --build-arg REPO_URL=https://foss.heptapod.net/zandronum/zandronum-stable \
    --build-arg REPO_TAG=ZA_3.2.1 \
    --build-arg VARIANT=official \
    -t rcdailey/zandronum-server:official-local .

# Build with plain Docker (TSPG variant)
docker build \
    --build-arg REPO_URL=http://hg.code.sf.net/p/zandronum-tspg/code \
    --build-arg REPO_TAG=TSPGv32 \
    --build-arg VARIANT=tspg \
    -t rcdailey/zandronum-server:tspg-local .
```

There are no tests, linters, or formatters configured for this project.

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`) triggers on every push and pull request. It
builds both variants for linux/amd64 and linux/arm64. Images are pushed to Docker Hub only from the
`master` branch.

**Required secrets**: `DOCKER_HUB_USERNAME`, `DOCKER_HUB_PASSWORD`

## Dockerfile Conventions

### Structure

The Dockerfile uses a multi-stage build pattern:

1. **Build stage** (`FROM ubuntu:22.04 AS build`): installs build tools, clones Zandronum source via
   Mercurial, applies patches, compiles with CMake + Ninja
2. **Runtime stage** (`FROM ubuntu:22.04`): copies only `/usr/local/` from build stage, installs
   minimal runtime dependencies

### Build Args

Three required build args control which Zandronum variant to build:

- `REPO_URL`: Mercurial repository URL
- `REPO_TAG`: Tag or commit hash to clone
- `VARIANT`: Build variant name (`official` or `tspg`); selects variant-specific patches

### RUN Command Style

- MUST prefix multi-line RUN commands with `true \` as a no-op first line to allow uniform `&&`
  continuation on subsequent lines
- MUST use `&&` to chain commands within a single RUN layer (never separate RUN instructions for
  logically grouped steps)
- SHOULD redirect noisy output to `/dev/null` for clean build logs (e.g., `apt-get install ... >
  /dev/null`)
- MUST use `apt-get` with `-qq` and `--no-install-recommends`

```dockerfile
# Correct pattern
RUN true \
    && apt-get update -qq \
    && apt-get install -qq --no-install-recommends \
        package-a \
        package-b \
        > /dev/null

# Wrong: missing true prefix, missing -qq, missing --no-install-recommends
RUN apt-get update && apt-get install package-a package-b
```

## Shell Script Conventions

### General

- MUST use `#!/usr/bin/env bash` shebang
- MUST set `set -exu` at the top of every script (exit on error, print commands, error on undefined
  variables)
- MUST use `[[ ]]` for conditionals (not `[ ]`)
- MUST use `(( ))` for arithmetic comparisons
- MUST quote all variable expansions (`"$VAR"`, not `$VAR`)
- Shell scripts MUST use LF line endings (enforced via `.gitattributes`)

### Naming

- Variables: `UPPERCASE_WITH_UNDERSCORES`
- Application-specific environment variables: `ZANDRONUM_` prefix
- Internal users/groups: descriptive lowercase names (`doomguy`, `zandronum`)

### Error Handling

- Guard against invalid state early with explicit checks and `exit 1`
- Use `|| true` to suppress expected non-zero exits (e.g., `useradd ... || true`)
- Use parameter default syntax (`${VAR-}`) for optional variables

### Process Execution

- MUST use `exec` when replacing the shell process with the target binary
- MUST use `gosu` (not `su` or `sudo`) for dropping privileges in containers
- MUST use `tini` as PID 1 init process (declared in ENTRYPOINT)

## Docker Compose Conventions

- Omit the top-level `version` attribute (obsolete in Compose v2)
- Volume mounts for read-only data SHOULD use `:ro` suffix
- Use `network_mode: host` as the recommended networking approach
- Use `>` for multi-line `command:` values for readability
- Zandronum CLI args use `-` prefix for options and `+` prefix for console commands

## Configuration File Conventions

Zandronum `.cfg` files in `examples/`:

- Use `set` for cvar assignment, `addmap` for map rotation entries
- One setting per line, no trailing comments
- Organize into logical groups: global settings, game mode settings, map lists
- String values use double quotes only when they contain spaces

## Patch System

Patches are organized by variant under `docker-files/patches/`:

```txt
docker-files/patches/
  common/        # Applied to all variants
  official/      # Only for official builds
  tspg/          # Only for TSPG builds
```

The Dockerfile applies `common/*.patch` first, then `$VARIANT/*.patch`. Files MUST:

- Use `.patch` extension
- Be UTF-8 encoded
- Apply cleanly against the target `REPO_TAG` with `patch -p1`

## Git Conventions

### Commits

- Use present tense, imperative mood (e.g., "Add feature", not "Added feature")
- Subject line under 60 characters
- No body paragraph required for straightforward changes

### Branches

- `master` is the default and publishing branch
- Feature branches for non-trivial changes

## Do

- Keep the Dockerfile minimal; only install what the runtime strictly needs
- Use multi-stage builds to avoid shipping build tools in the final image
- Pin base image OS versions (e.g., `ubuntu:22.04`, not `ubuntu:latest`)
- Clean up apt caches in the runtime stage (`rm -rf /var/lib/apt/lists/*`)
- Test image builds locally with `docker compose build` before pushing

## Don't

- Do not add build tools or compilers to the runtime stage
- Do not use `sudo` or `su` inside containers; use `gosu`
- Do not use `latest` tags for base images
- Do not commit `.log` files (excluded via `.gitignore`)
- Do not push images from non-master branches (CI enforces this)
- Do not run the container with `--user`/`user:`; use `ZANDRONUM_UID`/`ZANDRONUM_GID` instead

## When Stuck

- Read the README.md for user-facing documentation and usage examples
- Check `examples/multiple-servers/` for Docker Compose patterns
- Refer to existing shell scripts for established conventions
- Ask a clarifying question rather than guessing
