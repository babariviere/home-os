# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/ucore:stable@sha256:d661066ac68e3b4f7b61ce7f0c57a88af2c6c301bf6fc9cce87bf0aa09b7716a


RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

COPY /quadlets /usr/share/containers/systemd

# Logically bind the caddy image to this OS image so `bootc upgrade` pulls it
# into the bootc store instead of Caddy being recompiled from source at boot.
RUN mkdir -p /usr/lib/bootc/bound-images.d && \
    ln -sf /usr/share/containers/systemd/caddy/caddy.container \
      /usr/lib/bootc/bound-images.d/caddy.container

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
