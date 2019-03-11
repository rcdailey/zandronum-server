#!/usr/bin/env bash
set -exu

# Do not allow container to be started as non-root user
if (( "$(id -u)" != 0 )); then
    echo "You must run the container as root. To specify a custom user,"
    echo "use the ZANDRONUM_UID and ZANDRONUM_GID environment variables"
    exit 1
fi

 # Create the group for the server process
[[ -n "$ZANDRONUM_GID" ]] && GID_OPTION="--gid $ZANDRONUM_GID"
groupadd zandronum --force ${GID_OPTION-}

# Create the user for the server process
[[ -n "$ZANDRONUM_UID" ]] && UID_OPTION="--uid $ZANDRONUM_UID"
useradd doomguy --create-home ${UID_OPTION-} \
    --shell /sbin/nologin \
    --group zandronum \
    || true # Do not fail if user already exists

# Start the zandronum-server process with local user & group
gosu doomguy:zandronum zandronum-server -host "$@"
