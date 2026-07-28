# home-os

A custom [bootc](https://github.com/bootc-dev/bootc) image for my home server, built on [Universal Blue's ucore](https://github.com/ublue-os/ucore) (Fedora CoreOS-based). The entire OS is an immutable OCI container image that updates itself atomically.

## Services

All services run as rootless Podman containers managed by [systemd quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html), baked into the image at build time.

| Service | Purpose |
|---|---|
| [Caddy](https://caddyserver.com/) | Reverse proxy with automatic HTTPS via Cloudflare DNS |
| [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Cloudflare Tunnel exposing only `books.babariviere.com` publicly |
| [Paperless-ngx](https://docs.paperless-ngx.com/) | Document management |
| [SilverBullet](https://silverbullet.md/) | Markdown note-taking / wiki |
| [BookOrbit](https://bookorbit.app/) | Self-hosted ebook / audiobook / comic library |
| [Shelfmark](https://github.com/calibrain/shelfmark) | Ebook search & request tool (download-only, feeds BookOrbit Book Dock) |
| [Home Assistant](https://www.home-assistant.io/) | Home automation hub (also the Apple HomeKit bridge) |
| [Matter Server](https://github.com/matter-js/matterjs-server) | Matter controller for Home Assistant |

## How it works

- The OS image is built via GitHub Actions and pushed to `ghcr.io/babariviere/home-os`
- The server runs `bootc-fetch-apply-updates` to automatically pull and apply OS updates
- Container images are kept up to date via `podman-auto-update`
- Each service group has its own isolated Podman network, bridged to Caddy for reverse proxy access
- TLS certificates are provisioned automatically by Caddy using Cloudflare DNS-01 challenges

## Networking

The host lives on the **Servers** VLAN (10). Most services need nothing more than that.

Matter-over-Thread is the exception. The HomePods that act as Thread border routers
are on the **Default** VLAN (1), and Matter-over-Thread requires the Home Assistant
host to share an L2 segment with a Thread border router (link-local Router
Advertisements and Neighbor Discovery do not cross VLANs, so cross-VLAN routing
cannot reach the Thread mesh).

To bridge this without moving the host onto the Default VLAN, a tagged VLAN-1
sub-interface (`enp1s0.1`) is baked into the image as a NetworkManager keyfile
(`build_files/system-connections/thread-vlan1.nmconnection`, installed by
`build_files/build.sh`). It:

- gives the host an IPv4 + IPv6 presence on the Default VLAN (with `never-default`
  so the default route stays on the Servers VLAN), enough for Matter/AirPlay mDNS
  and for reaching the Thread border routers;
- adds a static route into the Thread mesh: `fda8:17d7:bdc4::/64` via a HomePod's
  link-local (`fe80::cd:4530:355d:40c`).

Caveats:

- The static route is pinned to one HomePod's link-local and the current Thread
  prefix. If that HomePod is removed or the Thread network is re-formed (prefix
  changes), the route in the keyfile must be updated.
- Home Assistant's `configuration.yaml` also needs `http.trusted_proxies` for the
  Caddy `home.babariviere.com` vhost; that lives in the container's state dir
  (`/var/lib/homeassistant`), not in this image.

### Firewall

firewalld is active and its zone definitions are baked into the image
(`build_files/firewalld/zones/*.xml`, installed by `build_files/build.sh`), so the
host firewall is reproducible on reprovision. Interface-to-zone mapping is done by
NetworkManager:

- `enp1s0` (Servers VLAN) -> zone `public`
- `enp1s0.1` (Default VLAN) -> zone `FedoraServer` (set in the keyfile)

Home Assistant's HomeKit Bridge advertises on `enp1s0` (`192.168.1.173`) and needs
mDNS plus its HAP ports open. Both zones open `mdns` and `21063-21080/tcp` (the
HomeKit Bridge is on `21064`, camera accessories on `21066`-`21068`; the range
leaves headroom for more bridge instances). The `public` zone also carries the
published service ports (Caddy-fronted `8000`/`3000`).

Note there is no host firewall restricting the Default-VLAN leg (`enp1s0.1`) itself,
so the host is reachable from the Default VLAN. Locking that down is a future
improvement.

## Remote access

Everything is private by default: services are reachable on the LAN and over
Tailscale only, and the router forwards no inbound ports (Caddy still gets valid
certificates via Cloudflare DNS-01, which needs no inbound connectivity).

The one exception is **BookOrbit**, which must be reachable by a Kobo e-reader
that cannot join the tailnet. Rather than expose the whole host, only
`books.babariviere.com` is published through a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/):

- `cloudflared.service` (`quadlets/cloudflared`) runs the `cloudflare/cloudflared`
  image on the caddy network and dials out to the Cloudflare edge, so the router
  still forwards no inbound ports. Its `config.yml` ingress exposes only
  `books.babariviere.com`; everything else returns 404 and, more importantly, no
  other hostname has a public CNAME pointing at the tunnel.
- The tunnel forwards to a books-only Caddy listener on `:8080` (see
  `quadlets/caddy/Caddyfile`). That listener is not published to the host, so it
  is reachable only from inside the caddy network and serves a single vhost,
  meaning the tunnel can never reach any other site. TLS is terminated at the
  Cloudflare edge; the internal hop is plaintext.
- `APP_URL` stays `https://books.babariviere.com` (web UI, emails, OIDC), also
  served over LAN/tailnet by Caddy's `*.babariviere.com` listener. The Kobo talks
  to `books.babariviere.com` directly: BookOrbit's Kobo sync builds every resource
  link from the request `Host`/`X-Forwarded-*` headers, which cloudflared and
  Caddy forward. Point the Kobo's `api_endpoint` at `https://books.babariviere.com`.

Tunnel bootstrap is a one-time step this repo cannot bake in (the credentials are
a runtime secret): create the tunnel, run `cloudflared tunnel route dns` to add
the public CNAME, and store the credentials JSON as the podman secret
`cloudflared-creds`. The tunnel UUID lives in `quadlets/cloudflared/config.yml`.


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
