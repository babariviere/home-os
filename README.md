# home-os

A custom [bootc](https://github.com/bootc-dev/bootc) image for my home server, built on [Universal Blue's ucore](https://github.com/ublue-os/ucore) (Fedora CoreOS-based). The entire OS is an immutable OCI container image that updates itself atomically.

## Services

All services run as rootless Podman containers managed by [systemd quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html), baked into the image at build time.

| Service | Purpose |
|---|---|
| [Caddy](https://caddyserver.com/) | Reverse proxy with automatic HTTPS via Cloudflare DNS |
| [Paperless-ngx](https://docs.paperless-ngx.com/) | Document management |
| [SilverBullet](https://silverbullet.md/) | Markdown note-taking / wiki |
| [BookOrbit](https://bookorbit.app/) | Self-hosted ebook / audiobook / comic library |
| [Shelfarr](https://shelfarr.org/) | Ebook / audiobook request & download manager (Jellyseerr for books) |
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
that cannot join the tailnet. Rather than expose the whole host, a single
service is published through [Tailscale Funnel](https://tailscale.com/kb/1223/funnel):

- `tailscale-funnel-bookorbit.service` (baked into the image) funnels the
  node's public `https://ducky.taild3c37.ts.net` to the local BookOrbit port
  (`127.0.0.1:3000`). TLS is terminated by Tailscale; no router port-forward.
- `APP_URL` stays `https://books.babariviere.com` (web UI, emails, OIDC),
  served over LAN/tailnet by Caddy. The Kobo talks to the Funnel hostname
  directly: BookOrbit's Kobo sync builds every resource link from the request
  `Host`/`X-Forwarded-*` headers, not `APP_URL`, so Funnel forwarding those
  headers is enough. Point the Kobo's `api_endpoint` at the Funnel URL.

Funnel requires tailnet-side policy that this repo cannot set: in the admin
console enable **HTTPS certificates** and grant `ducky` the `funnel`
node attribute (`nodeAttrs` with `"attr": ["funnel"]`). Without it the unit
starts but Funnel stays disabled.


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
