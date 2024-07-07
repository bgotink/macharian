#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Install & Configure tailscale

if ! has_command tailscale; then
	curl -fsSL https://tailscale.com/install.sh | sh
fi

tailscale up

# Install & configure Nginx

if ! has_command nginx; then
	apt install nginx
fi

if ! has_command cerbot; then
	apt install certbot python3-certbot-nginx
fi

cat <<EOF > /etc/nginx/home-proxy.conf
location / {
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Real-IP       \$remote_addr;

	proxy_set_header Host            \$host;

	proxy_http_version 1.1;

	proxy_set_header Upgrade         \$http_upgrade;
	proxy_set_header Connection      \$proxy_connection;

	proxy_pass https://$LOCAL_IP_CYTHERIS;
}
EOF

cat <<EOF > /etc/nginx/sites-available/proxy-_name_
server {
	server_name _name_.$SECRET_HOST;

	include /etc/nginx/home-proxy.conf;
}
EOF

cat <<'EOF' > /etc/nginx/conf.d/proxy_upgrade.conf
map $http_upgrade $proxy_connection {
	default upgrade;
	''      close;
}
EOF

echo "server_tokens off;" > /etc/nginx/conf.d/server_tokens.conf

for file in $EXPOSED_SUBDOMAINS; do
	if [ ! -f /etc/nginx/sites-available/proxy-$file ]; then
		sed -e 's/_name_/$file/' </etc/nginx/sites-available/proxy-_name_ >/etc/nginx/sites-available/proxy-$file

		ln -s ../sites-available/proxy-$file /etc/nginx/sites-enabled/proxy-$file

		certbot --nginx -d $file.$SECRET_HOST
	fi
done

# Set up fail2ban

if ! has_command fail2ban-client; then
	apt install fail2ban
fi

### TODO include configuration for fail2ban ###

# Firewall

ufw enable

ufw default allow outgoing
ufw default deny incoming

ufw allow 'Nginx HTTP'
ufw allow 'Nginx HTTPS'
ufw allow OpenSSH

ufw allow from tailscale0
ufw allow from anywhere on tailscale0

