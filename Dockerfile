FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -qq --no-install-recommends \
      wget \
      gnupg \
      gosu \
      tini \
    && wget -O - http://debian.drdteam.org/drdteam.gpg | apt-key add - \
    && echo 'deb http://debian.drdteam.org/ stable multiverse' >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -qq --no-install-recommends zandronum-server \
    && cp ./usr/games/zandronum/libcrypto.so.1.0.0 ./usr/lib/x86_64-linux-gnu/ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV INSTALL_DIR=/usr/games/zandronum

# Environment variables used to map host UID/GID to internal
# user used to launch zandronum-server.
ENV ZANDRONUM_UID= \
    ZANDRONUM_GID=

# Entrypoint
COPY ./docker-files/entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
