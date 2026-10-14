#!/bin/bash
# AgentOS Build Script
# Builds a bootable x86-64 Linux image

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
ISO_FILE="${BUILD_DIR}/agentos.iso"
QCOW2_FILE="${BUILD_DIR}/agentos.qcow2"
DISK_SIZE="10G"

# Colors for output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
NC='[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_requirements() {
    log_info "Checking build requirements..."
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        log_error "This script must be run on x86_64 Linux"
        exit 1
    fi
    for tool in qemu-img debootstrap xorriso; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Missing tool: $tool"
            exit 1
        fi
    done
    log_info "Requirements satisfied"
}

create_build_dirs() {
    mkdir -p "$BUILD_DIR" "$ROOTFS_DIR"
    log_info "Build directories created"
}

bootstrap_rootfs() {
    log_info "Bootstrapping root filesystem..."
    rm -rf "$ROOTFS_DIR"/*
    if command -v debootstrap &> /dev/null; then
        sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/
        log_info "Debian bootstrap complete"
    else
        log_warn "debootstrap not available"
    fi
}

install_system_packages() {
    log_info "Installing system packages..."
    sudo chroot "$ROOTFS_DIR" apt update
    sudo chroot "$ROOTFS_DIR" apt install -y         systemd-sysv         linux-image-amd64         grub-pc-bin         qemu-guest-agent         sudo openssh-server         vim hostname iproute2 iputils-ping procps
    log_info "Packages installed"
}

configure_system() {
    log_info "Configuring system..."
    echo 'agentos' > "$ROOTFS_DIR/etc/hostname"
    cat > "$ROOTFS_DIR/etc/hosts" << 'HOSTS'
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
HOSTS
    sudo chroot "$ROOTFS_DIR" useradd -m -s /bin/bash agent || true
    log_info "System configured"
}

install_grub() {
    log_info "Installing GRUB bootloader..."
    sudo grub-install --target=x86_64-pc --boot-directory="$ROOTFS_DIR/boot" "$ROOTFS_DIR"
    sudo chroot "$ROOTFS_DIR" update-grub
    log_info "GRUB installed"
}

create_image() {
    log_info "Creating disk image..."
    qemu-img create -f qcow2 -o preallocation=metadata "$QCOW2_FILE" "$DISK_SIZE"
    log_info "Image created: $QCOW2_FILE"
}

create_iso() {
    log_info "Creating ISO..."
    local ISO_DIR="${BUILD_DIR}/iso"
    mkdir -p "$ISO_DIR"/{EFI/BOOT,boot}
    echo "AgentOS" > "$ISO_DIR/boot/README.txt"
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs -o "$ISO_FILE" -V "AGENTOS" -J -R "$ISO_DIR"
    fi
    log_info "ISO created: $ISO_FILE"
}

build() {
    log_info "Starting AgentOS build..."
    create_build_dirs
    bootstrap_rootfs
    install_system_packages
    configure_system
    install_grub
    create_image
    create_iso
    log_info "Build complete!"
    log_info "Artifacts: $QCOW2_FILE, $ISO_FILE"
}

build "$@"
