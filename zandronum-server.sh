#!/usr/bin/env bash

# Set the working directory to the Zandronum installation dir. This is so it can find its own files,
# like zandronum.pk3, GeoIP.dat, etc.
cd /usr/local/games/zandronum
exec /usr/local/games/zandronum/zandronum-server "$@"
