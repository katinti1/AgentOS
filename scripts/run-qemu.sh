#!/bin/bash
# AgentOS QEMU Runner Script
# Runs AgentOS in QEMU for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QCOW2_FILE="${PROJECT_ROOT}/build/agentos.qcow2"
ISO_FILE="${PROJECT_ROOT}/build/agentos.iso"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
BOOT_LOG="${PROJECT_ROOT}/build/boot.log"

RAM="2048"
CPU="2"
display_type="gtk"
USE_SNAPSHOT=false
ENABLE_KVM=true
BOOT_TIMEOUT="60"
BOOT_MARKER="agentos_boot_complete"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -m RAM     Memory in MB (default: ${RAM})"
    echo "  -c CPU     Number of CPUs (default: ${CPU})"
    echo "  --display Display method: gtk, sdl, curses, none"
    echo "  --snapshot Use overlay snapshot"
    echo "  --no-kvm  Disable KVM"
    echo "  --timeout Seconds to wait for boot (default: ${BOOT_TIMEOUT})"
    echo "  -h, --help Show help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m) RAM="$2"; shift 2 ;;
        -c) CPU="$2"; shift 2 ;;
        --display) display_type="$2"; shift 2 ;;
        --snapshot) USE_SNAPSHOT=true; shift ;;
        --no-kvm) ENABLE_KVM=false; shift ;;
        --timeout) BOOT_TIMEOUT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU can only run on x86_64 architecture"
    echo "Current architecture: $ARCH"
    echo "To build on ARM64: use 'scripts/build.sh on x86-64 Linux"
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU not found"
    echo "Install with: sudo apt install qemu-system-x86"
    exit 1
fi

# Check for either QCOW2 disk or ISO
USE_QCOW2=false
USE_ISO=false

if [ -f "$QCOW2_FILE" ] && [ -s "$QCOW2_FILE" ]; then
    USE_QCOW2=true
elif [ -f "$ISO_FILE" ] && [ -s "$ISO_FILE" ]; then
    USE_ISO=true
else
    echo -e "\033[0;31m[ERROR]\033[0m Neither valid disk image nor ISO found"
    echo "Run ./scripts/build.sh first"
    exit 1
fi

# Ensure build directory exists for logs
mkdir -p "${PROJECT_ROOT}/build"

echo -e "\033[0;32m[INFO]\033[0m Starting AgentOS in QEMU..."
echo -e "\033[0;32m[INFO]\033[0m Using: $(basename "$QCOW2_FILE" 2>/dev/null || basename "$ISO_FILE")"

QEMU_CMD="qemu-system-x86_64"

if [ "$ENABLE_KVM" = true ] && [ -e /dev/kvm ]; then
    QEMU_CMD="$QEMU_CMD -enable-kvm"
fi

if [ "$USE_QCOW2" = true ]; then
    QEMU_CMD="$QEMU_CMD -m $RAM -smp $CPU -drive file=$QCOW2_FILE,format=qcow2,if=virtio"
else
    QEMU_CMD="$QEMU_CMD -m $RAM -smp $CPU -cdrom $ISO_FILE -boot d"
fi

# Direct kernel boot if kernel and initrd available
KERNEL=$(ls $ROOTFS_DIR/boot/vmlinuz* 2>/dev/null | head -1)
INITRD=$(ls $ROOTFS_DIR/boot/initrd* 2>/dev/null | head -1)

if [ -n "$KERNEL" ] && [ -n "$INITRD" ]; then
    echo -e "\033[1;33m[INFO]\033[0m Using direct kernel boot"
    QEMU_CMD="$QEMU_CMD -kernel $KERNEL -initrd $INITRD -append \"console=ttyS0 root=/dev/sda1 rw\""
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

# Serial console for boot monitoring
QEMU_CMD="$QEMU_CMD -serial file:$BOOT_LOG -serial mon:stdio"

if [ "$USE_SNAPSHOT" = true ]; then
    QEMU_CMD="$QEMU_CMD -snapshot"
fi

echo -e "\033[0;32m[INFO]\033[0m Running: $QEMU_CMD"

# Run QEMU with timeout
if timeout "$BOOT_TIMEOUT" $QEMU_CMD 2>&1; then
    echo ""
    echo -e "\033[0;32m[INFO]\033[0m QEMU exited successfully"
    if [ -f "$BOOT_LOG" ]; then
        echo ""
        echo "===== BOOT LOG ====="
        cat "$BOOT_LOG"
        echo "==================="
        # Check for boot marker
        if grep -q "agentos_boot_complete" "$BOOT_LOG" 2>/dev/null; then
            echo -e "\033[0;32m[PASS]\033[0m Boot complete marker found"
        else
            echo -e "\033[1;33m[WARN]\033[0m Boot complete marker not found"
        fi
    fi
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo -e "\033[0;31m[ERROR]\033[0m QEMU exited with code: $EXIT_CODE"
    if [ -f "$BOOT_LOG" ]; then
        echo ""
        echo "===== BOOT LOG (last 50 lines) ====="
        tail -50 "$BOOT_LOG"
        echo "===================================="
    fi
    exit $EXIT_CODE
fi