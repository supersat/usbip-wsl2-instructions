#!/bin/sh

KERNEL_REPO_URL=https://github.com/Microsoft/WSL2-Linux-Kernel
KERNEL_DIR=WSL2-Linux-Kernel

KERNEL_VER=$(uname -r | cut --delimiter='-' --fields=1)
echo "Running kernel $KERNEL_VER"

BRANCH=$(git ls-remote --refs --tags $KERNEL_REPO_URL | cut --delimiter=/ --fields=3 | grep $KERNEL_VER)
echo "Found branch $BRANCH"

git clone $KERNEL_REPO_URL -b linux-msft-5.4.72 --depth=1 $KERNEL_DIR
cd $KERNEL_DIR

patch -p1 < ../genalloc.patch

cat /proc/config.gz | gzip -d > .config
scripts/config -m GENERIC_ALLOCATOR
scripts/config -m USB
scripts/config -e USB_SUPPORT
scripts/config -m USB_COMMON
scripts/config -e USB_ARCH_HAS_HCD
scripts/config -m USBIP_CORE
scripts/config -m USBIP_VHCI_HCD
scripts/config --set-val USBIP_VHCI_HC_PORTS 8
scripts/config --set-val USBIP_VHCI_NR_HCS 1
scripts/config -d USB_PCI
make olddefconfig

make LOCALVERSION= -j $(nproc)
sudo make modules_install
