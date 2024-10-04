#!/usr/bin/env bash
set -euxo pipefail

cd "$(dirname "$0")/.."

. _shared/setup.sh

# Debian doesn't come with sudo pre-installed
if ! has_command sudo; then
	apt install -y sudo
	usermod -a -G sudo "$MAIN_USER"
fi

# Block root login
if ! (head -n1 /etc/shadow | grep --quiet "root:!"); then
	passwd -l root
fi

if ! has_command virt-install; then
	apt install -y --no-install-recommends \
		qemu-system libvirt-clients libvirt-daemon-system
fi

if ! has_command osinfo-query; then
	apt install -y libosinfo-bin
fi

if ! (osinfo-query os | grep --quiet ubuntu24.04); then
	pushd /tmp >/dev/null 2>&1
	# This URL will be out of date if we ever re-run this script...
	wget osinfo.tar.xz https://releases.pagure.org/libosinfo/osinfo-db-20240523.tar.xz
	osinfo-db-import --local osinfo.tar.xz
	popd >/dev/null 2>&1
fi

has_vm() {
	if virsh list  | grep --quiet "$1"; then
		return 0;
	else
		return 1;
	fi
}

has_lv() {
	if lvs | grep --quiet "$1"; then
		return 0;
	else
		return 1;
	fi
}

UBUNTU_VERSION="24.04"
UBUNTU_ISO="/home/iso/ubuntu-$UBUNTU_VERSION-live-server-amd64.iso"
ensure_has_ubuntu_iso() {
	if ! [ -f "$UBUNTU_ISO" ]; then
		mkdir -p /home/iso
		wget -o "$UBUNTU_ISO" "https://ftp.belnet.be/ubuntu-releases/$UBUNTU_VERSION/ubuntu-$UBUNTU_VERSION-live-server-amd64.iso"
	fi
}

VG_NAME=macharian-sector-vg

create_ubuntu_vm() {
	ensure_has_ubuntu_iso

	virt-install \
		--virt-type kvm \
		--network bridge=br0 \
		--location "$UBUNTU_ISO,kernel=casper/vmlinuz,initrd=casper/initrd" \
		--os-variant "ubuntu$UBUNTU_VERSION" \
		--graphics none \
		--console pty,target_type=serial \
		--extra-args "console=ttyS0" \
		"$@"
}

if ! has_vm andosk; then
	if ! has_lv andosk; then
		lvcreate --size 20G --name andosk "$VG_NAME"
	fi

	create_ubuntu_vm \
		--name andosk \
		--disk path="/dev/$VG_NAME/andosk" \
		--vcpus=1 \
		--memory 1024
fi

if ! has_vm cytheris; then
	if ! has_lv cytheris-root; then
		lvcreate --size 100G --name cytheris-root "$VG_NAME"
	fi
	if ! has_lv cytheris-data; then
		lvcreate --size 500G --name cytheris-data "$VG_NAME"
	fi

	create_ubuntu_vm \
		--name cytheris \
		--disk "path=/dev/$VG_NAME/cytheris-root" \
		--disk "path=/dev/$VG_NAME/cytheris-data" \
		--vcpus=12 \
		--memory 32768
fi

if ! has_vm yix; then
	if ! has_lv yix-root; then
		lvcreate --size 20G --name yix-root "$VG_NAME"
	fi
	if ! has_lv yix-data; then
		lvcreate --size 500G --name yix-data "$VG_NAME"
	fi

	create_ubuntu_vm \
		--name yix \
		--disk "path=/dev/$VG_NAME/yix-root" \
		--disk "path=/dev/$VG_NAME/yix-data" \
		--vcpus=2 \
		--memory 8192
fi

if ! has_vm gallosque; then
	if ! has_lv gallosque; then
		lvcreate --size 20G --name gallosque "$VG_NAME"
	fi

	create_ubuntu_vm \
		--name gallosque \
		--disk "path=/dev/$VG_NAME/gallosque" \
		--vcpus=1 \
		--memory 4096
fi

if ! has_vm persepolis; then
	mkdir /home/haos
	pushd /home/haos >/dev/null 2>&1

	HAOS_VERSION=12.3
	wget "https://github.com/home-assistant/operating-system/releases/download/$HAOS_VERSION/haos_ova-$HAOS_VERSION.qcow2.xz"
	xz -d "haos_ova-$HAOS_VERSION.qcow2.xz"

	virsh pool-create-as --name persepolis-pool --type dir --target /home/haos

	virt-install \
		--import \
		--name persepolis \
		--memory 4096 \
		--vcpus 1 \
		--cpu host \
		--disk "/home/haos/haos_ova-$HAOS_VERSION.qcow2,format=qcow2,bus=virtio" \
		--network bridge=br0 \
		--osinfo detect=on,require=off \
		--graphics none \
		--noautoconsole \
		--boot uefi

	popd >/dev/null 2>&1
fi

# TODO unlock rootfs remotely
# https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/
