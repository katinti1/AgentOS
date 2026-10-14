#!/bin/bash
# AgentOS QEMU Runner Script
# Runs AgentOS in QEMU for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QCOW2_FILE="${PROJECT_ROOT}/build/agentos.qcow2"

# Default configuration
RAM="2048"
CPU="2"
GUI="gtk"
NET_IFACE="user"
USE_SNAPSHOT=false
ENABLE_KVM=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m RAM     Memory in MB (default: ${RAM})"
    echo "  -c CPU     Number of CPUs (default: ${CPU})"
    echo "  -n         Use user networking"
    echo "  --snapshot Use overlay snapshot (discard changes on exit)"
    echo "  --display Display method: gtk, sdl, curses, none"
    echo "  --no-kvm  Disable KVM acceleration"
    echo "  -h, --help Show this help"
    echo ""
    echo "Example:"
    echo "  $0 -m 4096 -c 4 --snapshot"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m)
            RAM="$2"
            shift 2
            ;;
        -c)
            CPU="$2"
            shift 2
            ;;
        -n)
            NET_IFACE="user"
            shift
            ;;
        --snapshot)
            USE_SNAPSHOT=true
            shift
            ;;
        --display)
            GUI="$2"
            shift 2
            ;;
        --no-kvm)
            ENABLE_KVM=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}[ERROR]${NC} QEMU can only run on x86_64 architecture"
    echo -e "${RED}[ERROR]${NC} Current architecture: $ARCH"
    echo -e "${RED}[ERROR]${NC} AgentOS cannot be tested on ARM/Android"
    exit 1
fi

# Check for QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} QEMU not found"
    echo -e "${RED}[ERROR]${NC} Install with: apt install qemu-system-x86"
    exit 1
fi

# Check for disk image
if [ ! -f "$QCOW2_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Disk image not found"
    echo -e "${RED}[ERROR]${NC} Run ./scripts/build.sh first"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Starting AgentOS in QEMU..."
echo -e "${GREEN}[INFO]${NC} Memory: ${RAM}MB, CPUs: ${CPU}"

# Build QEMU command
QEMU_CMD="qemu-system-x86_64"

# KVM acceleration
if [ "$ENABLE_KVM" = true ]; then
    if [ -e /dev/kvm ]; then
        QEMU_CMD="$QEMU_CMD -enable-kvm"
        echo -e "${GREEN}[INFO]${NC} KVM acceleration enabled"
    else
        echo -e "${YELLOW}[WARN]${NC} KVM not available, using emulation"
    fi
fi

# Memory and CPU
QEMU_CMD="$QEMU_CMD -m $RAM -smp $CPU"

# Display
case $GUI in
    gtk)
        QEMU_CMD="$QEMU_CMD -display gtk"
        ;;
    sdl)
        QEMU_CMD="$QEMU_CMD -display sdl"
        ;;
    curses)
        QEMU_CMD="$QEMU_CMD -display curses"
        ;;
    none)
        QEMU_CMD="$QEMU_CMD -nographic"
        ;;
esac

# Disk
if [ "$USE_SNAPSHOT" = true ]; then
    QEMU_CMD="$QEMU_CMD -snapshot"
fi
QEMU_CMD="$QEMU_CMD -drive if=none,file=$QCOW2_FILE,id=drive0,format=qcow2 -device virtio-blk-pci,drive=drive0"

# Network
case $NET_IFACE in
    user)
        QEMU_CMD="$QEMU_CMD -netdev user,id=net0 -device virtio-net-pci,netdev=net0"
        ;;
    tap)
        QEMU_CMD="$QEMU_CMD -netdev tap,id=net0,ifname=tap0 -device virtio-net-pci,netdev=net0"
        ;;
esac

# Sound (optional)
# QEMU_CMD="$QEMU_CMD -audiodev pa,id=audio0 -device ich9-intel-hda -device hda-output,audiodev=audio0"

# Additional QEMU options for debugging
QEMU_CMD="$QEMU_CMD -serial mon:stdio"

echo -e "${GREEN}[INFO]${NC} Command: $QEMU_CMD"
echo ""

# Run QEMU
exec $QEMU_CMD