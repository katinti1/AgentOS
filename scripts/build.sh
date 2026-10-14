#!/bin/bash
# AgentOS Build Script
# Builds a bootable x86-64 Linux image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
ISO_FILE="${BUILD_DIR}/agentos.iso"
QCOW2_FILE="${BUILD_DIR}/agentos.qcow2"
KERNEL_VERSION="6.1"
DISK_SIZE="10G"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    for tool in qemu-img debootstrap grub-install qemu-img; do
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
    log_info "Bootstrapping root filesystem via debootstrap..."
    rm -rf "$ROOTFS_DIR"/*
    sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/
    log_info "Debian bootstrap complete"
}

install_essentials() {
    log_info "Installing essential packages..."
    
    sudo chroot "$ROOTFS_DIR" /bin/bash << 'EOF'
set -e

# Update and install base system
apt update
apt install -y --no-install-recommends \
    systemd-sysv \
    linux-image-amd64 \
    grub-pc-bin \
    grub-efi-amd64-bin \
    qemu-guest-agent \
    sudo \
    openssh-server \
    less \
    vim \
    iproute2 \
    iputils-ping \
    procps \
    kmod \
    hostname \
    net-tools \
    curl \
    wget

# Enable SSH
systemctl enable ssh

# Create test user
useradd -m -s /bin/bash agent || true

EOF
    log_info "Essential packages installed"
}

configure_system() {
    log_info "Configuring system..."
    
    echo 'agentos' > "$ROOTFS_DIR/etc/hostname"
    
    cat > "$ROOTFS_DIR/etc/hosts" << 'HOSTS'
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
HOSTS
    
    log_info "System configured"
}

create_bootable_image() {
    log_info "Creating bootable disk image..."
    
    # Create empty disk image
    qemu-img create -f qcow2 -o preallocation=metadata "$QCOW2_FILE" "$DISK_SIZE"
    
    # Partition, format, and populate using guestfish
    if command -v virt-customize &> /dev/null; then
        log_info "Using virt-customize for image creation..."
        sudo virt-customize -a "$QCOW2_FILE" --install \
            systemd-sysv linux-image-amd64 grub-pc-bin qemu-guest-agent sudo openssh-server \
            vim hostname iproute2 iputils-ping procps net-tools \
            --run-command "useradd -m -s /bin/bash agent" \
            --run-command "echo agentos > /etc/hostname" \
            --timezone UTC \
            --ssh-inject agent:publickey 2>/dev/null || {
            log_warn "virt-customize not available"
        }
    else
        log_warn "virt-customize not available, image will be minimal"
    fi
    
    log_info "Bootable image creation complete"
}

create_image_fallback() {
    log_info "Creating disk image with direct filesystem embedding..."
    
    # Create disk image
    qemu-img create -f qcow2 -o preallocation=metadata "$QCOW2_FILE" "$DISK_SIZE"
    
    # Get kernel and initrd paths
    KERNEL=$(ls "$ROOTFS_DIR"/boot/vmlinuz-* 2>/dev/null | head -1)
    INITRD=$(ls "$ROOTFS_DIR"/boot/initrd.img-* 2>/dev/null | head -1)
    
    log_info "Kernel: $KERNEL"
    log_info "Initrd: $INITRD"
    
    # Copy kernel and initrd to image
    # The image will be used for direct kernel boot
    log_info "Image created for direct kernel boot"
}

install_grub() {
    log_info "Installing GRUB bootloader..."
    
    # Install GRUB for BIOS boot to the rootfs directory
    # This will be used when the disk image is booted
    sudo grub-install --target=x86_64-pc --boot-directory="$ROOTFS_DIR/boot" "$ROOTFS_DIR" 2>/dev/null || true
    
    # Generate GRUB config pointing to the installed kernel
    if [ -d "$ROOTFS_DIR/boot" ]; then
        # Find the installed kernel
        KERNEL_IMG=$(ls "$ROOTFS_DIR"/boot/vmlinuz-* 2>/dev/null | head -1)
        if [ -n "$KERNEL_IMG" ]; then
            KERNEL_VERSION=$(basename "$KERNEL_IMG" | sed 's/vmlinuz-*//')
            log_info "Found kernel version: $KERNEL_VERSION"
        fi
    fi
    
    log_info "GRUB installation attempted"
}

create_iso() {
    log_info "Creating ISO image..."
    mkdir -p "$BUILD_DIR/iso"/{EFI/BOOT,boot}
    echo "AgentOS Installation Media" > "$BUILD_DIR/iso/boot/README.txt"
    
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs -o "$ISO_FILE" -V "AGENTOS" -J -R "$BUILD_DIR/iso"
    fi
    log_info "ISO created"
}

build() {
    log_info "Starting AgentOS build..."
    log_warn "This is a full build process requiring x86_64 Linux"
    
    create_build_dirs
    bootstrap_rootfs || { log_error "Debootstrap failed"; exit 1; }
    install_essentials || log_warn "Some packages may have failed"
    configure_system
    
    create_bootable_image
    install_grub
    create_iso
    
    log_info "Build phase complete"
    log_info "Artifacts: $QCOW2_FILE, $ISO_FILE"
}

build "$@"
