#!/usr/bin/env bash

# Add sbin to path

if echo "$PATH" | grep --quiet -v /sbin; then
	PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
fi

# Helpers

has_command() {
	if command -v "$1" >/dev/null 2>&1; then
		return 0;
	else
		return 1;
	fi
}

CERTBOT_DIGITALOCEAN_TOKEN_FILE=/root/digitalocean-certbot.ini
install_certbot() {
	if ! has_command certbot; then
		apt install certbot python3-certbot-dns-digitalocean
	fi

	if ! [ -f "$CERTBOT_DIGITALOCEAN_TOKEN_FILE" ]; then
		echo "dns_digitalocean_token = $DIGITALOCEAN_TOKEN" > "$CERTBOT_DIGITALOCEAN_TOKEN_FILE"
		chmod 600 "$CERTBOT_DIGITALOCEAN_TOKEN_FILE"
	fi
}

# Shared setup logic

# run apt update so we don't have to think about it in individual setup scripts
apt update

# install useful commands
has_command curl || apt install -y curl
has_command wget || apt install -y wget

# load encrypted secrets
has_command age || apt install -y age

if ! has_command sops; then
	pushd /tmp >/dev/null 2>&1
	# renovate: datasource=github-releases depName=getsops/sops
	wget -o sops.deb -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb
	dpkg -i sops.deb
	popd >/dev/null 2>&1
fi

if ! [ -f ~/.config/sops/age/keys.txt ]; then
	mkdir -p ~/.config/sops/age/

	read -rsp "Enter the age secret key (AGE-SECRET-KEY-...) $ "

	set +x
	echo "$REPLY" > ~/.config/sops/age/keys.txt
	unset REPLY
	set -x
fi

sops -d _shared/secrets.env | source

# install qemu tooling if needed
if hostnamectl | grep --quiet "Hardware Vendor: QEMU"; then
	if ! (apt list qemu-guest-agent | grep --quiet -F "[installed]"); then
		apt install -y qemu-guest-agent
	fi
fi
