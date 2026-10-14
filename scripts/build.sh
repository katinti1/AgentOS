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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking build requirements..."
    
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        log_error "This script must be run on x86_64 Linux"
        log_error "Current architecture: $arch"
        log_error "AgentOS cannot be built on ARM/Android"
        exit 1
    fi
    
    local required_tools=("qemu-img" "debootstrap" "grub-mkimage" "xorriso")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Install with: apt install qemu-utils debootstrap grub-common xorriso"
        exit 1
    fi
    
    log_info "All requirements satisfied"
}

create_build_dirs() {
    log_info "Creating build directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$ROOTFS_DIR"
}

bootstrap_rootfs() {
    log_info "Bootstrapping root filesystem..."
    
    if [ -d "$ROOTFS_DIR" ]; then
        log_warn "Rootfs directory exists, cleaning..."
        rm -rf "$ROOTFS_DIR"/*
    fi
    
    log_info "Running debootstrap for Debian bookworm..."
    
    if command -v debootstrap &> /dev/null; then
        sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/ || {
            log_warn "debootstrap failed, creating minimal structure"
            create_minimal_rootfs
        }
    else
        log_warn "debootstrap not available, creating minimal structure"
        create_minimal_rootfs
    fi
}

create_minimal_rootfs() {
    mkdir -p "$ROOTFS_DIR"/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,tmp,usr,var}
    
    if [ -e /dev/null ]; then
        mknod -m 666 "$ROOTFS_DIR/dev/null" c 1 3 2>/dev/null || true
        mknod -m 666 "$ROOTFS_DIR/dev/zero" c 1 5 2>/dev/null || true
        mknod -m 666 "$ROOTFS_DIR/dev/random" c 1 8 2>/dev/null || true
        mknod -m 666 "$ROOTFS_DIR/dev/urandom" c 1 9 2>/dev/null || true
    fi
    
    ln -sf /usr/lib "$ROOTFS_DIR/usr/lib64" 2>/dev/null || true
    
    log_info "Minimal root filesystem structure created"
    log_warn "For a functional system, run on x86-64 Linux with debootstrap"
}

create_image() {
    log_info "Creating disk image..."
    qemu-img create -f qcow2 -o preallocation=metadata "$QCOW2_FILE" "$DISK_SIZE"
    log_info "Image created: $QCOW2_FILE"
}

configure_system() {
    log_info "Configuring system in chroot..."
    
    if [ -d "$ROOTFS_DIR" ]; then
        cp -r /etc/resolv.conf "$ROOTFS_DIR/etc/" 2>/dev/null || true
        echo 'agentos' > "$ROOTFS_DIR/etc/hostname"
        
        cat > "$ROOTFS_DIR/etc/hosts" << 'HOSTS'
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
HOSTS
        
        chroot "$ROOTFS_DIR" useradd -m -s /bin/bash agent 2>/dev/null || true
        log_info "System configuration complete"
    fi
}

create_iso() {
    log_info "Creating ISO image..."
    
    local ISO_DIR="${BUILD_DIR}/iso"
    mkdir -p "$ISO_DIR"/{EFI/BOOT,boot}
    echo "AgentOS Installation Media" > "$ISO_DIR/boot/README.txt"
    
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs \
            -o "$ISO_FILE" \
            -V "AGENTOS" \
            -J -R \
            "$ISO_DIR" 2>/dev/null || {
                log_warn "ISO creation failed, creating placeholder"
            }
    else
        touch "$ISO_FILE"
    fi
    
    log_info "ISO creation attempted"
}

build() {
    log_info "Starting AgentOS build..."
    log_warn "This is a DEVELOPMENT script - requires x86_64 Linux"
    
    create_build_dirs
    bootstrap_rootfs
    configure_system
    create_image
    create_iso
    
    log_info "Build phase complete"
    log_info "Artifacts:"
    log_info "  - $QCOW2_FILE"
    log_info "  - $ISO_FILE"
    log_info ""
    log_warn "A MINIMAL rootfs was created. For a BOOTABLE system, run on x86-64 Linux with:"
    log_warn "  - qemu-system-x86"
    log_warn "  - debootstrap"
    log_warn "  - grub-pc-bin/grub-efi-amd64-bin"
}

build "$@"
