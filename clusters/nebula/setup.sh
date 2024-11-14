#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Install & Configure tailscale

if ! has_command tailscale; then
	curl -fsSL https://tailscale.com/install.sh | sh
fi

sudo tailscale up --accept-routes

# Install & configure Nginx

if ! has_command nginx; then
	sudo apt install -y nginx
fi

install_certbot python3-certbot-nginx

cat <<EOF | sudo tee /etc/nginx/home-proxy.conf
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

cat <<EOF | sudo tee /etc/nginx/sites-available/proxy-_name_
server {
	server_name _name_.$SECRET_HOST;

	include /etc/nginx/home-proxy.conf;
}
EOF

cat <<'EOF' | sudo tee /etc/nginx/conf.d/proxy_upgrade.conf
map $http_upgrade $proxy_connection {
	default upgrade;
	''      close;
}
EOF

echo "server_tokens off;" | sudo tee /etc/nginx/conf.d/server_tokens.conf

for file in $EXPOSED_SUBDOMAINS; do
	if [ ! -f /etc/nginx/sites-available/proxy-$file ]; then
		sed -e 's/_name_/$file/' </etc/nginx/sites-available/proxy-_name_ | sudo tee /etc/nginx/sites-available/proxy-$file

		sudo ln -s ../sites-available/proxy-$file /etc/nginx/sites-enabled/proxy-$file
		sudo certbot --nginx -d $file.$SECRET_HOST
	fi
done

# Set up fail2ban

if ! has_command fail2ban-client; then
	sudo apt -y install fail2ban
fi

### TODO include configuration for fail2ban ###

# Firewall

if ! has_command ufw; then
	sudo apt install -y ufw
fi

sudo ufw enable

sudo ufw default allow outgoing
sudo ufw default deny incoming

sudo ufw allow 'Nginx HTTP'
sudo ufw allow 'Nginx HTTPS'
sudo ufw allow OpenSSH

sudo ufw allow in on tailscale0
sudo ufw allow out on tailscale0
