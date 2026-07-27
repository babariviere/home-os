#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

dnf5 install -y htop tuned incus

echo "containers:2147483647:2147483648" > /etc/subuid
echo "containers:2147483647:2147483648" > /etc/subgid
echo "root:1000000:1000000000" >> /etc/subuid
echo "root:1000000:1000000000" >> /etc/subgid

systemctl enable podman.socket
systemctl enable podman-auto-update.timer
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable cockpit.service
systemctl enable tailscaled.service
systemctl enable tuned.service
systemctl enable incus.service

# Ensure we reboot on update
sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --apply --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service

# Tagged VLAN leg for Matter-over-Thread.
# ducky lives on the Servers VLAN (10) but the HomePods/Thread border routers are
# on the Default VLAN (1). Matter-over-Thread needs the HA host on the same L2 as
# a Thread border router, so this adds a VLAN-1 sub-interface (enp1s0.1) plus a
# static route into the Thread mesh via a HomePod. See README for details.
install -Dm0600 /ctx/system-connections/thread-vlan1.nmconnection \
  /etc/NetworkManager/system-connections/thread-vlan1.nmconnection

# Firewall: ship the firewalld zone definitions so the host firewall is
# reproducible on reprovision. public = enp1s0 (Servers VLAN),
# FedoraServer = default/enp1s0.1 (Default VLAN). Both open mDNS + the HomeKit
# HAP port range (21063-21080) for the Home Assistant HomeKit Bridge; public
# also carries the published service ports. Interfaces are mapped to zones by
# NetworkManager. See README for details.
install -Dm0644 /ctx/firewalld/zones/public.xml /etc/firewalld/zones/public.xml
install -Dm0644 /ctx/firewalld/zones/FedoraServer.xml /etc/firewalld/zones/FedoraServer.xml

# Shared Book Dock folder for Shelfarr -> BookOrbit handoff. Created at boot with
# owner 1000:1000 so the idmapped volume mounts resolve to container-root.
install -Dm0644 /ctx/tmpfiles/book-dock.conf /usr/lib/tmpfiles.d/book-dock.conf
