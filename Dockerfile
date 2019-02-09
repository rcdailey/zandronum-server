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
        libsdl1.2-dev

RUN true \
    && hg clone https://bitbucket.org/Torr_Samaho/zandronum-stable -r ZA_3.0 zandronum \
    && cd zandronum \
    && cmake -G Ninja -W no-dev -D CMAKE_BUILD_TYPE=Release -D SERVERONLY=1 . \
    && cmake --build . \
    && mkdir -p /usr/local/games/zandronum \
    && cp zandronum-server zandronum.pk3 /usr/local/games/zandronum/ \
    && ln -s /usr/local/games/zandronum/zandronum-server /usr/local/bin/zandronum-server

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

# Required so the server can find zandronum.pk3
ENV DOOMWADDIR=/usr/local/games/zandronum

ENTRYPOINT ["tini", "--", "zandronum-server"]
