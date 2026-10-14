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
    
    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        log_error "This script must be run on x86_64 Linux"
        log_error "Current architecture: $ARCH"
        log_error "AgentOS cannot be built on ARM/Android"
        exit 1
    fi
    
    # Check for required tools
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
    
    # Use debootstrap to create Debian base system
    # This is a placeholder - actual implementation depends on requirements
    log_warn "Debian bootstrap requires network access and time..."
    log_warn "See docs/build-guide.md for detailed instructions"
    
    # For now, create minimal structure
    mkdir -p "$ROOTFS_DIR"/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,tmp,usr,var}
    
    # Create device nodes
    MAKEDEV="$ROOTFS_DIR/dev"
    if [ -e /dev/null ]; then
        mknod -m 666 "$MAKEDEV/null" c 1 3 2>/dev/null || true
        mknod -m 666 "$MAKEDEV/zero" c 1 5 2>/dev/null || true
        mknod -m 666 "$MAKEDEV/random" c 1 8 2>/dev/null || true
        mknod -m 666 "$MAKEDEV/urandom" c 1 9 2>/dev/null || true
    fi
    
    # Create essential symlinks
    ln -sf /usr/lib /usr/lib64 2>/dev/null || true
    ln -sf ../proc/self/fd /dev/fd 2>/dev/null || true
    
    log_info "Root filesystem structure created"
    log_warn "This is a minimal skeleton. See docs/build-guide.md for full debootstrap"
}

create_image() {
    log_info "Creating disk image..."
    
    # Create QCOW2 image
    qemu-img create -f qcow2 -o preallocation=metadata "$QCOW2_FILE" "$DISK_SIZE"
    
    log_info "Image created: $QCOW2_FILE"
}

create_iso() {
    log_info "Creating ISO image..."
    
    # Create ISO structure
    local ISO_DIR="${BUILD_DIR}/iso"
    mkdir -p "$ISO_DIR"/{EFI/BOOT,boot}
    
    # This is a placeholder
    # Actual implementation would include:
    # - Bootloader files
    # - Kernel
    # - Initramfs
    # - Installer components
    
    log_warn "ISO creation is a placeholder"
    log_warn "See docs/build-guide.md for full implementation"
    
    # Create minimal ISO
    echo "AgentOS Installation Media" > "$ISO_DIR/boot/README.txt"
    
    # Create hybrid ISO
    xorriso -as mkisofs \
        -o "$ISO_FILE" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c boot.cat \
        -b boot/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "$ISO_DIR" || true
    
    log_info "ISO placeholder created"
}

build() {
    log_info "Starting AgentOS build..."
    
    check_requirements
    create_build_dirs
    bootstrap_rootfs
    create_image
    create_iso
    
    log_info "Build completed!"
    log_info "Images:"
    log_info "  - $QCOW2_FILE"
    log_info "  - $ISO_FILE"
    log_info ""
    log_warn "This is a PRELIMINARY build system"
    log_warn "See docs/build-guide.md for full implementation"
    log_warn "Actual bootable images require complete debootstrap"
}

# Run build
build "$@"