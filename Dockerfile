# Build stage for compiling Zandronum
FROM ubuntu:rolling AS build
WORKDIR /build
RUN true \
    && apt-get update \
    && apt-get install -yy --no-install-recommends \
        ca-certificates \
        mercurial \
        g++ \
        cmake \
        ninja-build \
        libssl1.0-dev \
        libsdl1.2-dev \
        wget

# So we can use bash arrays (default /bin/sh doesn't support this)
SHELL ["/bin/bash", "-c"]

# Build Zandronum
RUN true \
    && hg clone https://bitbucket.org/Torr_Samaho/zandronum-stable -r ZA_3.0 zandronum \
    && cd zandronum \
    && cmake -G Ninja -W no-dev -D CMAKE_BUILD_TYPE=Release -D SERVERONLY=1 . \
    && cmake --build .

# Install Zandronum
ARG INSTALL_DIR=/usr/local/games/zandronum
COPY zandronum-server.sh /usr/local/bin/zandronum-server
RUN true \
    && COPY_PATTERNS=(\
        zandronum-server \
        zandronum.pk3 \
    ) \
    && cd zandronum \
    && mkdir -p $INSTALL_DIR \
    && cp "${COPY_PATTERNS[@]}" $INSTALL_DIR \
    && chmod a+x /usr/local/bin/zandronum-server

# Install GeoIP.dat
RUN true \
    && wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz \
    && tar xvzf GeoLite2-Country.tar.gz \
    && cp GeoLite2-Country_*/GeoLite2-Country.mmdb $INSTALL_DIR/GeoIP.dat

# Final stage for running the zandronum server.
# Copies over everything in /usr/local.
FROM ubuntu:rolling
COPY --from=build /usr/local/ /usr/local/
RUN true \
    && apt-get update \
    && apt-get install -yy --no-install-recommends \
        tini \
        libssl1.0 \
        libsdl1.2debian \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["tini", "--", "zandronum-server"]
