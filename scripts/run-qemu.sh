#!/bin/bash
# AgentOS QEMU Runner Script
# Runs AgentOS in QEMU for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QCOW2_FILE="${PROJECT_ROOT}/build/agentos.qcow2"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
KERNEL_IMAGE="${ROOTFS_DIR}/boot/vmlinuz*"
INITRD_IMAGE="${ROOTFS_DIR}/boot/initrd*"

RAM="2048"
CPU="2"
display_type="gtk"
USE_SNAPSHOT=false
ENABLE_KVM=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -m RAM     Memory in MB (default: ${RAM})"
    echo "  -c CPU     Number of CPUs (default: ${CPU})"
    echo "  --display Display method: gtk, sdl, curses, none"
    echo "  --snapshot Use overlay snapshot"
    echo "  --no-kvm  Disable KVM"
    echo "  -h, --help Show help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m) RAM="$2"; shift 2 ;;
        -c) CPU="$2"; shift 2 ;;
        --display) display_type="$2"; shift 2 ;;
        --snapshot) USE_SNAPSHOT=true; shift ;;
        --no-kvm) ENABLE_KVM=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU can only run on x86_64 architecture"
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU not found"
    exit 1
fi

if [ ! -f "$QCOW2_FILE" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m Disk image not found"
    echo -e "\033[0;31m[ERROR]\033[0m Run ./scripts/build.sh first"
    exit 1
fi

echo -e "\033[0;32m[INFO]\033[0m Starting AgentOS in QEMU..."

QEMU_CMD="qemu-system-x86_64"

if [ "$ENABLE_KVM" = true ] && [ -e /dev/kvm ]; then
    QEMU_CMD="$QEMU_CMD -enable-kvm"
fi

QEMU_CMD="$QEMU_CMD -m $RAM -smp $CPU -drive file=$QCOW2_FILE,format=qcow2,if=virtio"

# Check for kernel image in rootfs for direct boot
KERNEL=$(ls $ROOTFS_DIR/boot/vmlinuz* 2>/dev/null | head -1)
INITRD=$(ls $ROOTFS_DIR/boot/initrd* 2>/dev/null | head -1)

if [ -n "$KERNEL" ] && [ -n "$INITRD" ]; then
    echo "\033[1;33m[INFO]\033[0m Using direct kernel boot"
    QEMU_CMD="$QEMU_CMD -kernel $KERNEL -initrd $INITRD -append "console=ttyS0 root=/dev/sda1 rw""
fi

# Display
case $display_type in
    gtk) QEMU_CMD="$QEMU_CMD -display gtk" ;;
    sdl) QEMU_CMD="$QEMU_CMD -display sdl" ;;
    curses) QEMU_CMD="$QEMU_CMD -display curses" ;;
    none) QEMU_CMD="$QEMU_CMD -nographic" ;;
esac

# Network
QEMU_CMD="$QEMU_CMD -netdev user,id=net0 -device virtio-net-pci,netdev=net0"

# Serial console
QEMU_CMD="$QEMU_CMD -serial mon:stdio"

if [ "$USE_SNAPSHOT" = true ]; then
    QEMU_CMD="$QEMU_CMD -snapshot"
fi

echo -e "\033[0;32m[INFO]\033[0m Running: $QEMU_CMD"
exec $QEMU_CMD
