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

# Environment variables used to map host UID/GID to internal
# user used to launch zandronum-server.
ENV ZANDRONUM_UID= \
    ZANDRONUM_GID=

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
