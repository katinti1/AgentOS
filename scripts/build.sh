#!/bin/bash
# AgentOS Build Script - Creates a bootable x86-64 Debian-based Linux system
# Prerequisite: sudo apt install debootstrap grub-pc-bin grub-common qemu-system-x86_64 qemu-utils xorriso grub2-common

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
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
    log_info "===== STARTING AGENTOS BUILD ====="

    log_info "Checking architecture..."
    if [ "$(uname -m)" != "x86_64" ]; then
        log_error "This script must run on x86_64 Linux. Current: $(uname -m)"
        exit 1
    fi

    log_info "Checking build tools..."
    local missing_tools=()
    for tool in qemu-img qemu-system-x86_64 debootstrap grub-install grub-mkimage grub-mkrescue parted losetup mount; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    log_info "All required tools available"

    log_info "Stage 1: Creating build directories..."
    mkdir -p "$BUILD_DIR" "$ROOTFS_DIR" "$ISO_DIR/boot/grub" "$MOUNT_POINT"
    log_info "Build directory: $BUILD_DIR"
    log_info "Rootfs directory: $ROOTFS_DIR"

    log_info "Stage 2: Bootstrapping Debian bookworm root filesystem..."
    rm -rf "$ROOTFS_DIR"/*
    log_info "Running: sudo debootstrap --arch amd64 bookworm $ROOTFS_DIR http://deb.debian.org/debian/"
    sudo debootstrap --arch amd64 bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/ || {
        log_error "Debootstrap failed - check network connectivity"
        log_error "Ensure DNS is available and deb.debian.org is reachable"
        exit 1
    }
    log_info "Debian bootstrap complete"
    log_info "Rootfs created at: $ROOTFS_DIR"
    ls -la "$ROOTFS_DIR" 2>/dev/null | head -5 || log_warn "Could not list rootfs"

    log_info "Stage 3: Installing packages to root filesystem..."
    log_info "Running package installation (this may take several minutes)..."
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
echo "Package installation complete"
EOF
    log_info "Package installation complete"

    log_info "Stage 4: Configuring system..."
    echo 'agentos' | sudo tee "$ROOTFS_DIR/etc/hostname" > /dev/null
    cat << 'HOSTS' | sudo tee "$ROOTFS_DIR/etc/hosts" > /dev/null
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
HOSTS
    log_info "System configuration complete"

    # Create initramfs if update-initramfs is available
    sudo chroot "$ROOTFS_DIR" /usr/sbin/update-initramfs -u 2>/dev/null || true

    log_info "Stage 5: Locating kernel and initrd..."
    VMLINUX=$(ls "$ROOTFS_DIR"/boot/vmlinuz-* 2>/dev/null | head -1 || echo "")
    INITRD=$(ls "$ROOTFS_DIR"/boot/initrd.img-* 2>/dev/null | head -1 || echo "")

    if [ -z "$VMLINUX" ] || [ -z "$INITRD" ]; then
        log_error "Kernel or initrd not found in rootfs"
        log_error "Kernel files:"
        ls -la "$ROOTFS_DIR"/boot/ 2>/dev/null || log_warn "Could not list /boot"
        exit 1
    fi

    VMLINUX_NAME=$(basename "$VMLINUX")
    INITRD_NAME=$(basename "$INITRD")
    log_info "Kernel: $VMLINUX_NAME"
    log_info "Initrd: $INITRD_NAME"

    # Copy kernel and initrd to ISO for bootloader
    cp "$VMLINUX" "$ISO_DIR/boot/"
    cp "$INITRD" "$ISO_DIR/boot/"

    log_info "Stage 6: Creating RAW disk image for partitioning..."
    rm -f "$RAW_DISK" "$QCOW2_FILE"
    log_info "Creating $RAW_DISK size $DISK_SIZE..."
    qemu-img create -f raw "$RAW_DISK" "$DISK_SIZE" || {
        log_error "Failed to create RAW disk image"
        exit 1
    }
    log_info "Raw disk created"

    log_info "Stage 7: Partitioning RAW disk with GPT..."
    sudo parted "$RAW_DISK" mklabel gpt --script=- << 'PARTED'
mkpart primary ext4 1MiB 100%
set 1 boot on
PARTED

    if [ $? -ne 0 ]; then
        log_error "Partitioning failed"
        exit 1
    fi
    log_info "Partition table created"

    sleep 2

    log_info "Stage 8: Setting up loop device..."
    LOOP_DEV=$(sudo losetup --find --show --partscan "$RAW_DISK" 2>/dev/null)
    if [ -z "$LOOP_DEV" ]; then
        log_error "Failed to create loop device"
        log_warn "Ensure kernel supports loop devices and /dev/loop* exists"
        exit 1
    fi
    log_info "Loop device: $LOOP_DEV"

    # Verify partition exists
    if [ ! -b "${LOOP_DEV}p1" ]; then
        log_error "Partition ${LOOP_DEV}p1 not found after partscan"
        log_error "Devices available: ls -la ${LOOP_DEV}*"
        ls -la "${LOOP_DEV}"* 2>/dev/null || true
        exit 1
    fi
    log_info "Partition exists: ${LOOP_DEV}p1"

    log_info "Stage 9: Formatting partition as ext4..."
    sudo mkfs.ext4 "${LOOP_DEV}p1" || {
        log_error "Failed to format partition"
        exit 1
    }
    log_info "Partition formatted"

    log_info "Stage 10: Mounting and populating root filesystem..."
    sudo mount "${LOOP_DEV}p1" "$MOUNT_POINT"
    log_info "Copying rootfs to mounted partition..."
    sudo cp -a "$ROOTFS_DIR"/* "$MOUNT_POINT"/ || {
        log_error "Failed to copy rootfs"
        exit 1
    }
    log_info "Root filesystem populated"

    log_info "Stage 11: Installing GRUB to guest disk..."
    sudo grub-install --target=x86_64-pc --boot-directory="$MOUNT_POINT/boot" "$LOOP_DEV" || {
        log_error "GRUB installation failed"
        exit 1
    }
    log_info "GRUB installed"

    log_info "Stage 12: Generating GRUB configuration..."
    sudo chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

    # Create custom grub.cfg with correct kernel paths
    cat << 'GRUB' | sudo tee "$MOUNT_POINT/boot/grub/grub.cfg"
set timeout=5
set default=0
menuentry "AgentOS (Linux)" {
    linux /boot/vmlinuz root=/dev/sda1 ro quiet
    initrd /boot/initrd.img
}
GRUB
    log_info "GRUB configuration created"

    log_info "Stage 13: Unmounting and detaching..."
    sync
    sudo umount "$MOUNT_POINT"
    sudo losetup -d "$LOOP_DEV"
    log_info "Loop device detached"

    log_info "Stage 14: Converting RAW to QCOW2..."
    if [ ! -f "$RAW_DISK" ]; then
        log_error "RAW disk file not found"
        exit 1
    fi
    qemu-img convert -f raw -O qcow2 -o preallocation=metadata "$RAW_DISK" "$QCOW2_FILE" || {
        log_error "QCOW2 conversion failed"
        exit 1
    }
    rm -f "$RAW_DISK"
    log_info "RAW converted to QCOW2"

    log_info "Stage 15: Verifying QCOW2 image..."
    if [ ! -f "$QCOW2_FILE" ]; then
        log_error "QCOW2 file was not created"
        exit 1
    fi
    qemu-img check "$QCOW2_FILE" || {
        log_error "QCOW2 verification failed"
        exit 1
    }
    log_info "QCOW2 verified"
    qemu-img info "$QCOW2_FILE"

    log_info "Stage 16: Creating bootable installation ISO..."
    rm -rf "$ISO_DIR"/*
    mkdir -p "$ISO_DIR/boot/grub"

    # Copy kernel images with versioned names
    cp "$VMLINUX" "$ISO_DIR/boot/vmlinuz"
    cp "$INITRD" "$ISO_DIR/boot/initrd.img"

    # Create GRUB config with correct filenames
    cat << 'GRUB' | sudo tee "$ISO_DIR/boot/grub/grub.cfg"
set timeout=5
set default=0
menuentry "AgentOS (Linux)" {
    linux /boot/vmlinuz root=/dev/sda1 ro quiet
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

    log_info "Stage 17: Verifying ISO..."
    if [ ! -f "$ISO_FILE" ]; then
        log_error "ISO file was not created"
        exit 1
    fi
    if [ ! -s "$ISO_FILE" ]; then
        log_error "ISO file is empty"
        exit 1
    fi

    ISO_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo "0")
    if [ "$ISO_SIZE" -lt 1000000 ]; then
        log_error "ISO file is too small ($ISO_SIZE bytes)"
        exit 1
    fi
    log_info "ISO verified"

    # Print debug info for CI
    log_info "=========================================="
    log_info "BUILD COMPLETE"
    log_info "=========================================="
    log_info "pwd=$(pwd)"
    log_info "PROJECT_ROOT=$PROJECT_ROOT"
    log_info "ls -lah $BUILD_DIR/"
    ls -lah "$BUILD_DIR/" 2>/dev/null || log_warn "Could not list build dir"
    log_info "=========================================="

    log_info "QCOW2: $QCOW2_FILE ($(du -h "$QCOW2_FILE" | cut -f1))"
    log_info "ISO:   $ISO_FILE ($(du -h "$ISO_FILE" | cut -f1))"
    log_info "=========================================="
}

main "$@"