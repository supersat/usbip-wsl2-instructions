#!/bin/sh

KERNEL_REPO_URL=https://github.com/Microsoft/WSL2-Linux-Kernel
KERNEL_DIR=WSL2-Linux-Kernel

KERNEL_VER=$(uname -r | cut --delimiter='-' --fields=1)
echo "Running kernel $KERNEL_VER"

BRANCH=$(git ls-remote --refs --tags $KERNEL_REPO_URL | cut --delimiter=/ --fields=3 | grep $KERNEL_VER)
echo "Found branch $BRANCH"

git clone $KERNEL_REPO_URL -b linux-msft-5.4.72 --depth=1 $KERNEL_DIR
cd $KERNEL_DIR

# USB host support requires the generic allocator library, but it isn't
# included by default on WSL2 x64 builds, so apply a patch to enable building
# it as a module.
patch -p1 < ../genalloc.patch

cat /proc/config.gz | gzip -d > .config
scripts/config -m GENERIC_ALLOCATOR
scripts/config -m USB
scripts/config -e USB_SUPPORT
scripts/config -m USB_COMMON
scripts/config -m USB_MON
scripts/config -e USB_ARCH_HAS_HCD
scripts/config -m USBIP_CORE
scripts/config -m USBIP_VHCI_HCD
scripts/config --set-val USBIP_VHCI_HC_PORTS 8
scripts/config --set-val USBIP_VHCI_NR_HCS 1

# Add drivers for various USB peripherals. Modify this to taste,
# or use make menuconfig
scripts/config -m USB_ACM
scripts/config -m USB_PRINTER
scripts/config -m USB_WDM
scripts/config -m USB_TMC
scripts/config -m USB_STORAGE
scripts/config -m USB_SERIAL
scripts/config -e USB_SERIAL_GENERIC
scripts/config -m USB_SERIAL_SIMPLE
scripts/config -m USB_SERIAL_CP210X
scripts/config -m USB_SERIAL_FTDI_SIO
scripts/config -m USB_SERIAL_PL2303
scripts/config -m USB_NET_DRIVERS
scripts/config -m USB_USBNET
scripts/config -m USB_NET_CDCETHER
scripts/config -m USB_NET_CDC_NCM
scripts/config -m USB_NET_CDC_SUBSET
scripts/config -m USB_NET_CDC_SUBSET_ENABLE

scripts/config -m USB_HID
scripts/config -m HID
scripts/config -m HID_GENERAL

scripts/config -d USB_PCI
make olddefconfig

make LOCALVERSION= -j $(nproc)
sudo make modules_install

# Make USBIP userland tools
cd tools/usb/usbip
./autogen.sh
./configure
make -j $(nproc)
sudo make install
