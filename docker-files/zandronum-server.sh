#!/usr/bin/env bash

# Set the working directory to the Zandronum installation dir. This is so it can find its own files,
# like zandronum.pk3, GeoIP.dat, etc.
cd "INSTALL_DIR"
exec "INSTALL_DIR/zandronum-server" "$@"
