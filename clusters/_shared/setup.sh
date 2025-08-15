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

is_apt_installed() {
  if dpkg -s "$2" >/dev/null 2>&1; then
  	return 0;
  else
  	return 1;
  fi
}

CERTBOT_DESEC_TOKEN_FILE=/root/desec-certbot.ini
install_certbot() {
	if ! is_apt_installed python3-venv; then
		# detect old installation
		if has_command certbot; then
			if [ $# -gt 0 ]; then
				sudo apt remove -y certbot python3-certbot-dns-digitalocean $(printf "python3-%s" "$@")
			else
				sudo apt remove -y certbot python3-certbot-dns-digitalocean
			fi
		fi

		sudo apt install -y python3-venv
	fi

	if ! [ -d /opt/certbot ]; then
		sudo python3 -m venv --upgrade-deps /opt/certbot
	fi

	if ! [ -f /opt/certbot/bin/certbot ]; then
		sudo /opt/certbot/bin/pip install certbot certbot-dns-desec "$@"
		sudo ln -s /opt/certbot/bin/certbot /usr/local/bin
	fi

	if ! [ -f "$CERTBOT_DESEC_TOKEN_FILE" ]; then
		echo "dns_desec_token = $DESEC_TOKEN" | sudo tee "$CERTBOT_DESEC_TOKEN_FILE" >/dev/null
		sudo chmod 400 "$CERTBOT_DESEC_TOKEN_FILE"
	fi
}

# Shared setup logic

# run apt update so we don't have to think about it in individual setup scripts
sudo apt update

# install useful commands
has_command curl || sudo apt install -y curl
has_command wget || sudo apt install -y wget

# load encrypted secrets
has_command age || sudo apt install -y age

if ! has_command sops; then
	pushd /tmp >/dev/null 2>&1
	# renovate: datasource=github-releases depName=getsops/sops
	wget -O sops.deb -L https://github.com/getsops/sops/releases/download/v3.10.2/sops_3.10.2_amd64.deb
	sudo dpkg -i sops.deb
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

source <(sops -d _shared/secrets.env)

# install qemu tooling if needed
if hostnamectl | grep --quiet "Hardware Vendor: QEMU"; then
	if ! (sudo apt list qemu-guest-agent | grep --quiet -F "[installed]"); then
		sudo apt install -y qemu-guest-agent
	fi
fi
