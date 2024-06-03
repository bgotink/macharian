#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Install & Configure tailscale

if ! has_command tailscale; then
	curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! [ -f /etc/sysctl.d/99-tailscale.conf ]; then
	cat <<EOF > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
fi


if ! [ -f /etc/networkd-dispatcher/routable.d/50-tailscale ]; then
	cat <<EOF > /etc/networkd-dispatcher/routable.d/50-tailscale
#!/bin/sh

ethtool -K enp1s0 rx-udp-gro-forwarding on rx-gro-list off
EOF
	chmod +x /etc/networkd-dispatcher/routable.d/50-tailscale
	/etc/networkd-dispatcher/routable.d/50-tailscale
fi

tailscale up --advertise-routes="$LOCAL_SUBNET"

# Firewall

ufw enable

ufw default allow outgoing
ufw default allow incoming

ufw allow from any to "$LOCAL_IP_CYTHERIS" port 443 comment 'Proxy to Cytheris'
ufw allow from any to "$LOCAL_IP_ANDOSK" port 53 comment 'Allow PiHole DNS'
ufw deny from any to "$LOCAL_SUBNET"
