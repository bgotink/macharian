#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

if ! has_command microk8s; then
	snap install microk8s --classic
fi

microk8s status --wait-ready

microk8s enable hostpath-storage dns metallb

microk8s enable community
microk8s enable cilium

if ! has_command kubectl; then
  cat <<'EOF' > /usr/local/sbin/kubectl
#!/bin/sh
exec microk8s kubectl "$@"
EOF
  chmod +x /usr/local/sbin/kubectl
fi

if ! has_command flux; then
	curl -SsL https://fluxcd.io/install.sh | bash
fi

kubectl create namespace flux-system

kubectl create secret generic sops-age \
	--namespace=flux-system \
	--from-file=age.agekey=/dev/stdin \
	< ~/.sops/age/keys.txt

flux bootstrap github \
  --personal \
  --owner=bgotink --repository=macharian --branch=main \
  --path=./clusters/cytheris \
  --components-extra image-reflector-controller,image-automation-controller
