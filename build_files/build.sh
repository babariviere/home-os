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

systemctl enable podman.socket
systemctl enable podman-auto-update.timer
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable cockpit.service
systemctl enable tailscaled.service

# Ensure we reboot on update
sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --apply --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
