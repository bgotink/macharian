#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Setup minio

if ! has_command minio; then
	pushd /tmp >/dev/null 2>&1
  wget -O minio.deb https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20240510014138.0.0_amd64.deb
  dpkg -i minio.deb
	popd >/dev/null 2>&1
fi

mkdir -p /srv/data

if ! (cat /etc/passwd | grep --quiet minio-user); then
	groupadd -r minio-user
	useradd -r --home /srv -g minio-user minio-user

	chown minio-user:minio-user /srv/
	chown minio-user:minio-user /srv/data
fi

if ! grep --quiet 9090 /etc/default/minio; then
	echo 'MINIO_VOLUMES="/srv/data"' > /etc/default/minio

	echo 'MINIO_OPTS="--address :9090 --console-address 127.0.0.1:9001"' >> /etc/default/minio

	echo "MINIO_ROOT_USER=admin" >> /etc/default/minio
	echo "MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD" >> /etc/default/minio
fi

systemctl enable --now minio

# Configure nginx

if ! has_command nginx; then
	apt install -y nginx
fi

install_certbot

if ! [ -f "/etc/letsencrypt/live/storage.${SECRET_HOST}/cert.pem" ]; then
	certbot \
		--dns-digitalocean \
		--dns-digitalocean-credentials "$CERTBOT_DIGITALOCEAN_TOKEN_FILE" \
		-d "storage.$SECRET_HOST" \
		--register-unsafely-without-email
fi

if ! grep --quiet "$SECRET_HOST" /etc/nginx/sites-enabled/default; then
	sed -e "s#\${SECRET_HOST}#${SECRET_HOST}#g" <yix/nginx-default.conf >/etc/nginx/sites-enabled/default
fi

systemctl enable --now nginx
systemctl reload nginx

# Configure firewall

ufw enable

ufw allow OpenSSH

ufw allow "Nginx HTTPS"
ufw allow 9000

ufw default allow outgoing
ufw default deny incoming
