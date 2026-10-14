# AgentOS Build Host Handoff

This document provides complete instructions for building AgentOS on an x86-64 Linux host.

## Transfer Repository

```bash
# Clone or copy the repository
git clone <repo-url> agentos
cd agentos
```

## System Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| Architecture | x86-64 (amd64) | x86-64 |
| OS | Debian 12, Ubuntu 22.04+ | Debian 12, Ubuntu 24.04 |
| CPU | 2 cores | 4+ cores |
| Memory | 4GB | 8GB+ |
| Disk Space | 20GB free | 50GB+ |
| Virtualization | None (for build) | KVM for testing |

## Install Build Dependencies

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y \
    qemu-system-x86 \
    qemu-utils \
    debootstrap \
    grub-pc-bin \
    grub-efi-amd64-bin \
    xorriso \
    dosfstools \
    mtools \
    git \
    make \
    curl \
    wget \
    sudo

# Optional: For kernel building
sudo apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev
```

## Build Process

```bash
# 1. Make scripts executable
chmod +x scripts/build.sh scripts/run-qemu.sh test/boot-test.sh

# 2. Run the build
./scripts/build.sh
```

## Automated Test

```bash
# Run tests
./test/boot-test.sh
```

Expected output on x86_64 Linux:
```
TEST: Architecture Check
STATUS: PASSED
DETAILS: Running on x86_64 host

TEST: Build Script Check
STATUS: PASSED
DETAILS: Script syntax valid

TEST: Tool Check
STATUS: PASSED
DETAILS: All required tools available

TEST: Image Check
STATUS: BLOCKED (until build runs)
```

## QEMU Boot Test

```bash
# Run with default settings
./scripts/run-qemu.sh

# Run with custom memory/CPU
./scripts/run-qemu.sh -m 4096 -c 4

# Run without display (headless)
./scripts/run-qemu.sh --display none

# Run with snapshot (discard changes on exit)
./scripts/run-qemu.sh --snapshot

# Run without KVM (slower, works in more environments)
./scripts/run-qemu.sh --no-kvm
```

## Expected Boot Sequence

When the image is bootable, you should see:
1. GRUB bootloader menu
2. Linux kernel messages scrolling
3. systemd initialization messages
4. systemd services starting
5. Login prompt (text mode) or display manager

## Build Artifacts

After successful build:
- `build/agentos.iso` - Installation ISO image
- `build/agentos.qcow2` - Virtual machine disk image
- `rootfs/` - Root filesystem directory
- `build/test-results.txt` - Test results

## Troubleshooting

### Build fails with architecture error
Ensure you're on x86_64 Linux:
```bash
uname -m  # Should return x86_64
```

### debootstrap fails
```bash
# Ensure network connectivity
curl -I http://deb.debian.org/

# Try alternative mirror
sudo debootstrap --arch amd64 bookworm rootfs http://archive.debian.org/debian/
```

### QEMU fails to start
```bash
# Check KVM availability
ls -la /dev/kvm

# Run without KVM
./scripts/run-qemu.sh --no-kvm
```

### GRUB installation fails
```bash
# Use BIOS target instead of UEFI
sudo grub-install --target=x86_64-pc --boot-directory=rootfs/boot rootfs
```

## Verification Checklist

After build completes:
- [ ] QCOW2 image exists and is non-empty (`ls -lh build/agentos.qcow2`)
- [ ] qemu-img info shows valid image
- [ ] Rootfs has basic structure (`ls rootfs/`)
- [ ] boot-test.sh shows Tool Check: PASSED
- [ ] QEMU boots to login prompt or kernel panic with console output

## Next Steps After Building

1. Verify kernel boots in QEMU
2. Test systemd services
3. Add Hermes Agent integration
4. Implement desktop environment
5. Create installer ISO