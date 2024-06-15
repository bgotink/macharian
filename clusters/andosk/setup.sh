#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Install pihole

if ! has_command pihole; then
	curl -sSL https://install.pi-hole.net | bash
fi

if ! [ -f /etc/dnsmasq.d/02-local-hosts.conf ]; then
	sops -d < andosk/dnsmsq-local-domains.conf > /etc/dnsmasq.d/02-local-hosts.conf
	pihole restartdns
fi

if ! [ -f /etc/dnsmasq.d/99-allow-non-local.conf  ]; then
	cat < andosk/dnsmasq-allow-non-local.conf > /etc/dnsmasq.d/99-allow-non-local.conf
	pihole restartdns
fi

# Setup certbot

install_certbot

if ! [ -f "/etc/letsencrypt/live/dns.${SECRET_HOST}/cert.pem" ]; then
	certbot \
		certonly \
		--dns-digitalocean \
		--dns-digitalocean-credentials "$CERTBOT_DIGITALOCEAN_TOKEN_FILE" \
		-d "dns.$SECRET_HOST" \
		--register-unsafely-without-email
fi

if ! grep --quiet -f "ssl.engine" /etc/lighttpd/lighttpd.conf; then
	cat <<EOF >> /etc/lighttpd/lighttpd.conf
ssl.engine              = "enable"
ssl.privkey             = "/etc/letsencrypt/live/dns.${SECRET_HOST}/privkey.pem"
ssl.pemfile             = "/etc/letsencrypt/live/dns.${SECRET_HOST}/fullchain.pem"
EOF
fi

if ! grep --quiet -F "Redirect all to admin" /etc/lighttpd/conf-enabled/15-pihole-admin.conf; then
	cat <<'EOF' >> /etc/lighttpd/conf-enabled/15-pihole-admin.conf

# Redirect all to admin
$HTTP["url"] == "/" {
    url.redirect = ("" => "/admin/")
}
EOF
fi

service lighttpd restart

# Configure firewall

ufw enable

ufw allow OpenSSH

ufw allow domain comment 'PiHole DNS'
ufw allow "Nginx HTTPS"

ufw default allow outgoing
ufw default deny incoming
