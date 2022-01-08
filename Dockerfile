# Build stage for compiling Zandronum
FROM ubuntu:20.04 AS build
WORKDIR /build
ENV DEBIAN_FRONTEND=noninteractive
RUN true \
    && apt-get update -qq \
    && apt-get install -qq --no-install-recommends \
        ca-certificates \
        mercurial \
        g++ \
        cmake \
        ninja-build \
        libssl-dev \
        libsdl1.2-dev \
        wget \
        patch \
        > /dev/null

# So we can use bash arrays (default /bin/sh doesn't support this)
SHELL ["/bin/bash", "-c"]

ARG REPO_URL
ARG REPO_TAG

# Clone the Repository
RUN true \
    && test -n "$REPO_URL" && test -n "$REPO_TAG" \
    && hg clone "$REPO_URL" -r "$REPO_TAG" zandronum

WORKDIR /build/zandronum

# Apply Manual Patches (make sure they are UTF-8 encoded)
COPY docker-files/patches /patches
RUN true \
    && shopt -s nullglob \
    && for p in /patches/*.patch; do patch -p1 < $p; done

# Build Zandronum
RUN true \
    && cmake -G Ninja -W no-dev \
        -D CMAKE_BUILD_TYPE=Release \
        -D SERVERONLY=1 \
        -D CMAKE_C_FLAGS="-w" \
        -D CMAKE_CXX_FLAGS="-w" \
        . \
    && cmake --build .

# Install Zandronum
ENV INSTALL_DIR=/usr/local/games/zandronum
COPY docker-files/zandronum-server.sh /usr/local/bin/zandronum-server
RUN true \
    && COPY_PATTERNS=(\
        zandronum-server \
        zandronum.pk3 \
    ) \
    && mkdir -p "$INSTALL_DIR" \
    && cp "${COPY_PATTERNS[@]}" "$INSTALL_DIR/" \
    && bin_path=/usr/local/bin/zandronum-server \
    && chmod a+x $bin_path \
    && sed -i "s|INSTALL_DIR|${INSTALL_DIR}|" $bin_path

# Install GeoIP.dat
COPY docker-files/GeoLite2-Country.mmdb "$INSTALL_DIR/GeoIP.dat"

# Final stage for running the zandronum server.
# Copies over everything in /usr/local.
FROM ubuntu:20.04
COPY --from=build /usr/local/ /usr/local/
RUN true \
    && apt-get update -qq \
    && apt-get install -qq --no-install-recommends \
        tini \
        libssl1.1 \
        libsdl1.2debian \
        gosu \
        > /dev/null \
    && rm -rf /var/lib/apt/lists/*

# Environment variables used to map host UID/GID to internal
# user used to launch zandronum-server.
ENV ZANDRONUM_UID= \
    ZANDRONUM_GID=

# Entrypoint
COPY ./docker-files/entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
