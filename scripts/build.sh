#!/bin/bash
# AgentOS Build Script - Creates a bootable x86-64 Debian-based Linux system
# Prerequisite: sudo apt install debootstrap grub-pc-bin grub-common qemu-system-x86 qemu-utils xorriso grub2-common

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
ISO_DIR="${BUILD_DIR}/iso"
RAW_DISK="${BUILD_DIR}/agentos.raw"
QCOW2_FILE="${BUILD_DIR}/agentos.qcow2"
DISK_SIZE="10G"
MOUNT_POINT="/tmp/agentos_mount"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    log_info "Cleaning up..."
    if [ -d "$MOUNT_POINT" ]; then
        sudo umount "$MOUNT_POINT" 2>/dev/null || true
    fi
    LOOP_DEV=$(losetup -j "$RAW_DISK" 2>/dev/null | cut -d: -f1 || echo "")
    if [ -n "$LOOP_DEV" ]; then
        sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
    rm -rf "$MOUNT_POINT" 2>/dev/null || true
    rm -f "$RAW_DISK" 2>/dev/null || true
}

trap cleanup EXIT

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
    local missing_tools=()
    for tool in qemu-img qemu-system-x86 debootstrap grub-install grub-mkimage grub-mkrescue parted losetup mount; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    log_info "All required tools available"

    log_info "Creating build directories..."
    mkdir -p "$BUILD_DIR" "$ROOTFS_DIR" "$ISO_DIR/boot/grub" "$MOUNT_POINT"

    log_info "Bootstrapping Debian bookworm root filesystem..."
    rm -rf "$ROOTFS_DIR"/*
    sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/ || {
        log_error "Debootstrap failed"
        exit 1
    }
    log_info "Debian bootstrap complete"

    log_info "Installing packages to root filesystem..."
    sudo chroot "$ROOTFS_DIR" /bin/bash << 'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y --no-install-recommends \
    systemd-sysv \
    linux-image-amd64 \
    grub-pc-bin \
    grub-common \
    grub2-common \
    qemu-guest-agent \
    sudo \
    openssh-server \
    vim \
    iproute2 \
    iputils-ping \
    procps \
    kmod \
    hostname \
    net-tools \
    curl \
    wget \
    grub2-signed || true
systemctl enable ssh
useradd -m -s /bin/bash agent || true
echo "agent ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/agent
chmod 440 /etc/sudoers.d/agent
apt clean
EOF
    log_info "Package installation complete"

    log_info "Configuring system..."
    echo 'agentos' | sudo tee "$ROOTFS_DIR/etc/hostname" > /dev/null
    cat << 'HOSTS' | sudo tee "$ROOTFS_DIR/etc/hosts" > /dev/null
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
HOSTS

    # Create a simple initramfs for boot
    sudo chroot "$ROOTFS_DIR" update-initramfs -u 2>/dev/null || true

    log_info "System configuration complete"

    # Get kernel and initrd filenames
    VMLINUX=$(ls "$ROOTFS_DIR"/boot/vmlinuz-* 2>/dev/null | head -1 || echo "")
    INITRD=$(ls "$ROOTFS_DIR"/boot/initrd.img-* 2>/dev/null | head -1 || echo "")

    if [ -z "$VMLINUX" ] || [ -z "$INITRD" ]; then
        log_error "Kernel or initrd not found in rootfs"
        exit 1
    fi

    VMLINUX_NAME=$(basename "$VMLINUX")
    INITRD_NAME=$(basename "$INITRD")
    log_info "Kernel: $VMLINUX_NAME"
    log_info "Initrd: $INITRD_NAME"

    # Copy kernel and initrd to ISO for bootloader
    cp "$VMLINUX" "$ISO_DIR/boot/"
    cp "$INITRD" "$ISO_DIR/boot/"

    log_info "Creating RAW disk image for partitioning..."
    rm -f "$RAW_DISK" "$QCOW2_FILE"
    qemu-img create -f raw "$RAW_DISK" "$DISK_SIZE"

    log_info "Partitioning RAW disk with GPT..."
    sudo parted "$RAW_DISK" mklabel gpt --script=- << 'PARTED'
mkpart primary ext4 1MiB 100%
set 1 boot on
PARTED

    sleep 2

    log_info "Setting up loop device..."
    LOOP_DEV=$(sudo losetup --find --show --partscan "$RAW_DISK" 2>/dev/null)
    if [ -z "$LOOP_DEV" ]; then
        log_error "Failed to create loop device"
        exit 1
    fi
    log_info "Loop device: $LOOP_DEV"

    # Verify partition exists
    if [ ! -b "${LOOP_DEV}p1" ]; then
        log_error "Partition ${LOOP_DEV}p1 not found"
        exit 1
    fi

    log_info "Formatting partition as ext4..."
    sudo mkfs.ext4 "${LOOP_DEV}p1"

    log_info "Mounting and populating root filesystem..."
    sudo mount "${LOOP_DEV}p1" "$MOUNT_POINT"
    sudo cp -a "$ROOTFS_DIR"/* "$MOUNT_POINT"/

    log_info "Installing GRUB to guest disk..."
    sudo grub-install --target=x86_64-pc --boot-directory="$MOUNT_POINT/boot" "$LOOP_DEV"

    log_info "Generating GRUB configuration..."
    sudo chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg || true

    # Create custom grub.cfg with correct kernel paths
    cat << 'GRUB' | sudo tee "$MOUNT_POINT/boot/grub/grub.cfg"
set timeout=5
set default=0
menuentry "AgentOS (Linux)" {
    linux /boot/vmlinuz root=/dev/sda1 ro quiet
    initrd /boot/initrd.img
}
GRUB

    log_info "Unmounting and detaching..."
    sync
    sudo umount "$MOUNT_POINT"
    sudo losetup -d "$LOOP_DEV"

    log_info "Converting RAW to QCOW2..."
    qemu-img convert -f raw -O qcow2 -o preallocation=metadata "$RAW_DISK" "$QCOW2_FILE"
    rm -f "$RAW_DISK"

    log_info "Verifying QCOW2 image..."
    if ! qemu-img check "$QCOW2_FILE" > /dev/null 2>&1; then
        log_error "QCOW2 verification failed"
        exit 1
    fi
    qemu-img info "$QCOW2_FILE"

    log_info "Creating bootable installation ISO..."
    rm -rf "$ISO_DIR"/*
    mkdir -p "$ISO_DIR/boot/grub"

    # Copy kernel images with versioned names
    cp "$VMLINUX" "$ISO_DIR/boot/vmlinuz"
    cp "$INITRD" "$ISO_DIR/boot/initrd.img"

    # Create GRUB config with correct filenames
    cat << 'GRUB' | sudo tee "$ISO_DIR/boot/grub/grub.cfg"
set timeout=5
set default=0
menuentry "AgentOS Live/System" {
    linux /boot/vmlinuz boot=live quickboot noprompt noeject  --
    initrd /boot/initrd.img
}
GRUB

    # Create a proper bootable ISO using grub-mkrescue
    log_info "Generating ISO with grub-mkrescue..."
    grub-mkrescue -o "$ISO_DIR/agentos.iso" "$ISO_DIR" || {
        log_warn "grub-mkrescue failed, trying xorriso fallback"
        xorriso -as mkisofs -o "$ISO_DIR/agentos.iso" \
            -b boot/grub/i386-pc/elegy_boot.img \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -V "AGENTOS" -J -R "$ISO_DIR" || {
            log_error "ISO creation failed"
            exit 1
        }
    }

    mv "$ISO_DIR/agentos.iso" "$ISO_FILE"

    log_info "Verifying ISO..."
    if [ ! -s "$ISO_FILE" ]; then
        log_error "ISO file is empty or missing"
        exit 1
    fi

    ISO_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo "0")
    if [ "$ISO_SIZE" -lt 1000000 ]; then
        log_error "ISO file is too small ($ISO_SIZE bytes)"
        exit 1
    fi

    log_info "=========================================="
    log_info "Build complete!"
    log_info "QCOW2: $QCOW2_FILE ($(du -h "$QCOW2_FILE" | cut -f1))"
    log_info "ISO:   $ISO_FILE ($(du -h "$ISO_FILE" | cut -f1))"
    log_info "=========================================="
}

main "$@"