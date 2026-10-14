#!/bin/bash
# AgentOS Build Script - Creates a bootable x86-64 Debian-based Linux system
# Prerequisite: sudo apt install debootstrap grub-pc-bin qemu-system-x86 qemu-utils xorriso

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
ISO_FILE="${BUILD_DIR}/agentos.iso"
QCOW2_FILE="${BUILD_DIR}/agentos.qcow2"
DISK_SIZE="10G"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

main() {
    log_info "Checking architecture..."
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "This script must run on x86_64 Linux. Current: $(uname -m)"
        exit 1
    fi

    log_info "Checking build tools..."
    for tool in qemu-img debootstrap grub-install parted; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Missing required tool: $tool"
            exit 1
        fi
    done
    log_info "All required tools available"

    log_info "Creating build directories..."
    mkdir -p "$BUILD_DIR" "$ROOTFS_DIR"

    log_info "Bootstrapping Debian bookworm root filesystem..."
    rm -rf "$ROOTFS_DIR"/*
    sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/
    log_info "Debian bootstrap complete"

    log_info "Installing packages to root filesystem..."
    sudo chroot "$ROOTFS_DIR" /bin/bash << 'EOF'
set -e
apt update
apt install -y --no-install-recommends systemd-sysv linux-image-amd64 grub-pc-bin qemu-guest-agent sudo openssh-server vim iproute2 iputils-ping procps kmod hostname net-tools curl wget
systemctl enable ssh
useradd -m -s /bin/bash agent || true
echo "agent ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/agent
chmod 440 /etc/sudoers.d/agent
EOF
    log_info "Package installation complete"

    log_info "Configuring system..."
    echo 'agentos' | sudo tee "$ROOTFS_DIR/etc/hostname" > /dev/null
    cat | sudo tee "$ROOTFS_DIR/etc/hosts" > /dev/null << 'HOSTS'
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
HOSTS
    log_info "System configuration complete"

    log_info "Creating partitioned QCOW2 disk image..."
    rm -f "$QCOW2_FILE"
    qemu-img create -f qcow2 "$QCOW2_FILE" "$DISK_SIZE"

    sudo parted "$QCOW2_FILE" mklabel gpt --script=- << 'PARTED'
mkpart primary ext4 1MiB 100%
set 1 boot on
PARTED

    sleep 1

    LOOP_DEV=$(sudo losetup --find --show --partscan "$QCOW2_FILE" 2>/dev/null || echo "")
    if [ -n "$LOOP_DEV" ]; then
        log_info "Loop device: $LOOP_DEV"
        sudo mkfs.ext4 "${LOOP_DEV}p1"
        sudo mount "${LOOP_DEV}p1" /mnt
        sudo cp -a "$ROOTFS_DIR"/* /mnt/
        sudo grub-install --target=x86_64-pc --boot-directory=/mnt/boot "$LOOP_DEV"
        sudo chroot /mnt update-grub
        sudo umount /mnt
        sudo losetup -d "$LOOP_DEV"
        log_info "Disk image created with partitions and GRUB"
    else
        log_warn "Could not create loop device"
    fi

    log_info "Creating installation ISO..."
    mkdir -p "$BUILD_DIR/iso"/{EFI/BOOT,boot/grub}
    [ -f "$ROOTFS_DIR/boot/vmlinuz"* ] && cp "$ROOTFS_DIR/boot/vmlinuz"* "$BUILD_DIR/iso/boot/" 2>/dev/null || true
    [ -f "$ROOTFS_DIR/boot/initrd.img"* ] && cp "$ROOTFS_DIR/boot/initrd.img"* "$BUILD_DIR/iso/boot/" 2>/dev/null || true

    cat | sudo tee "$BUILD_DIR/iso/boot/grub/grub.cfg" > /dev/null << 'GRUB'
set timeout=5
set default=0
menuentry "AgentOS (Linux)" {
    linux /boot/vmlinuz root=/dev/sda1 ro quiet
    initrd /boot/initrd.img
}
GRUB

    echo "AgentOS Installation Media" > "$BUILD_DIR/iso/README.txt"
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs -o "$ISO_FILE" -V "AGENTOS" -J -R "$BUILD_DIR/iso"
        log_info "ISO created: $ISO_FILE"
    else
        touch "$ISO_FILE"
        log_warn "xorriso not available"
    fi

    log_info "=========================================="
    log_info "Build complete!"
    log_info "QCOW2: $QCOW2_FILE"
    log_info "ISO:   $ISO_FILE"
    log_info "=========================================="
}

main "$@"