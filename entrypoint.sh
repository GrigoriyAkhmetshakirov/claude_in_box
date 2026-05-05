#!/bin/bash
set -e

# Fix Docker socket permissions for claude user.
# Docker Desktop on macOS passes the socket through a Linux VM,
# so the socket's GID inside the container may differ from the host.
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    if [ -n "$DOCKER_GID" ] && [ "$DOCKER_GID" != "0" ]; then
        # Non-root group — create matching group and add claude to it
        groupmod -g "$DOCKER_GID" docker 2>/dev/null \
            || groupadd -g "$DOCKER_GID" docker 2>/dev/null \
            || true
        usermod -aG "$DOCKER_GID" claude 2>/dev/null || true
    else
        # Socket owned by root:root — grant world access (safer than adding to root group)
        chmod 666 /var/run/docker.sock
    fi
fi

# Drop privileges to claude and execute CMD
exec gosu claude "$@"
