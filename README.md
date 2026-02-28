# home-os

A custom [bootc](https://github.com/bootc-dev/bootc) image for my home server, built on [Universal Blue's ucore](https://github.com/ublue-os/ucore) (Fedora CoreOS-based). The entire OS is an immutable OCI container image that updates itself atomically.

## Services

All services run as rootless Podman containers managed by [systemd quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html), baked into the image at build time.

| Service | Purpose |
|---|---|
| [Caddy](https://caddyserver.com/) | Reverse proxy with automatic HTTPS via Cloudflare DNS |
| [Paperless-ngx](https://docs.paperless-ngx.com/) | Document management |
| [SilverBullet](https://silverbullet.md/) | Markdown note-taking / wiki |
| [Homebridge](https://homebridge.io/) | Apple HomeKit bridge |

## How it works

- The OS image is built via GitHub Actions and pushed to `ghcr.io/babariviere/home-os`
- The server runs `bootc-fetch-apply-updates` to automatically pull and apply OS updates
- Container images are kept up to date via `podman-auto-update`
- Each service group has its own isolated Podman network, bridged to Caddy for reverse proxy access
- TLS certificates are provisioned automatically by Caddy using Cloudflare DNS-01 challenges

## Building

Requires [just](https://just.systems/) and Podman.

```bash
just build
```

To build a QCOW2 VM image or ISO for installation:

```bash
just build-qcow2
just build-iso
```
