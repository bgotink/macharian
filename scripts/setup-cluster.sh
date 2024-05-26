#!/usr/bin/env bash
set -euxo pipefail

if ! command -v age >/dev/null 2>&1; then
	apt install age
fi

if ! command -v sops >/dev/null 2>&1; then
	wget -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb
	dpkg -i sops_3.8.1_amd64.deb
	rm sops_3.8.1_amd64.deb
fi

if ! command -v microk8s >/dev/null 2>&1; then
	snap install microk8s --classic
fi

microk8s status --wait-ready

microk8s enable hostpath-storage dns metallb

microk8s enable community
microk8s enable cilium

if ! command -v kubectl >/dev/null 2>&1; then
  cat <<'EOF' > /usr/local/sbin/kubectl
#!/bin/sh
exec microk8s kubectl "$@"
EOF
  chmod +x /usr/local/sbin/kubectl
fi

if ! command -v flux >/dev/null 2>&1; then
	curl -SsL https://fluxcd.io/install.sh | bash
fi

read -p "Enter the age private key: " -r AGE_KEY

kubectl create namespace flux-system

echo "$AGE_KEY" | kubectl create secret generic sops-age \
	--namespace=flux-system \
	--from-file=age.agekey=/dev/stdin

flux bootstrap github \
  --personal \
  --owner=bgotink --repository=macharian --branch=main \
  --path=./clusters/cytheris \
  --components-extra image-reflector-controller,image-automation-controller
