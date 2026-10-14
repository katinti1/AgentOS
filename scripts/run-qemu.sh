#!/bin/bash
# AgentOS QEMU Runner Script
# Runs AgentOS in QEMU for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QCOW2_FILE="${PROJECT_ROOT}/build/agentos.qcow2"

RAM="2048"
CPU="2"
GUI="gtk"
NET_IFACE="user"
USE_SNAPSHOT=false
ENABLE_KVM=true

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

while [[ $# -gt 0 ]]; do
    case $1 in
        -m) RAM="$2"; shift 2 ;;
        -c) CPU="$2"; shift 2 ;;
        -n) NET_IFACE="user"; shift ;;
        --snapshot) USE_SNAPSHOT=true; shift ;;
        --display) GUI="$2"; shift 2 ;;
        --no-kvm) ENABLE_KVM=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU can only run on x86_64 architecture"
    echo -e "\033[0;31m[ERROR]\033[0m Current architecture: $ARCH"
    echo -e "\033[0;31m[ERROR]\033[0m AgentOS cannot be tested on ARM/Android"
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "\033[0;31m[ERROR]\033[0m QEMU not found"
    echo -e "\033[0;31m[ERROR]\033[0m Install with: apt install qemu-system-x86"
    exit 1
fi

if [ ! -f "$QCOW2_FILE" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m Disk image not found"
    echo -e "\033[0;31m[ERROR]\033[0m Run ./scripts/build.sh first"
    exit 1
fi

echo -e "\033[0;32m[INFO]\033[0m Starting AgentOS in QEMU..."
echo -e "\033[0;32m[INFO]\033[0m Memory: ${RAM}MB, CPUs: ${CPU}"

QEMU_CMD="qemu-system-x86_64"

if [ "$ENABLE_KVM" = true ] && [ -e /dev/kvm ]; then
    QEMU_CMD="$QEMU_CMD -enable-kvm"
    echo -e "\033[0;32m[INFO]\033[0m KVM acceleration enabled"
fi

QEMU_CMD="$QEMU_CMD -m $RAM -smp $CPU"

case $GUI in
    gtk) QEMU_CMD="$QEMU_CMD -display gtk" ;;
    sdl) QEMU_CMD="$QEMU_CMD -display sdl" ;;
    curses) QEMU_CMD="$QEMU_CMD -display curses" ;;
    none) QEMU_CMD="$QEMU_CMD -nographic" ;;
esac

if [ "$USE_SNAPSHOT" = true ]; then
    QEMU_CMD="$QEMU_CMD -snapshot"
fi
QEMU_CMD="$QEMU_CMD -drive if=none,file=$QCOW2_FILE,id=drive0,format=qcow2 -device virtio-blk-pci,drive=drive0"

case $NET_IFACE in
    user) QEMU_CMD="$QEMU_CMD -netdev user,id=net0 -device virtio-net-pci,netdev=net0" ;;
    tap) QEMU_CMD="$QEMU_CMD -netdev tap,id=net0,ifname=tap0 -device virtio-net-pci,netdev=net0" ;;
esac

QEMU_CMD="$QEMU_CMD -serial mon:stdio"

echo -e "\033[0;32m[INFO]\033[0m Running: $QEMU_CMD"
echo ""

exec $QEMU_CMD
