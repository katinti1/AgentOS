# AgentOS Build Host Handoff

This document provides complete instructions for building AgentOS on an x86-64 Linux host.

## Supported Host Architectures

| Architecture | Status | Notes |
|--------------|--------|-------|
| x86-64 (amd64) | ✅ Supported | Full build and boot test |
| ARM64/aarch64 | ⚠️ Development only | Static tests only, build blocked |

## Development from ARM64 (Android/Termux)

On ARM64 hosts (Android/Termux), you can:
- ✅ Run syntax validation tests
- ✅ Verify architecture detection
- ✅ Review build script logic
- ❌ Cannot build actual images (requires x86-64 QEMU/debootstrap)
- ❌ Cannot boot test (architecture mismatch)

### ARM64 Development Commands

```bash
# Verify current environment
uname -m  # Should show: aarch64
python3 --version  # For any scripting needs

# Run static tests (these work on ARM64)
./test/boot-test.sh  # Reports BLOCKED for build, PASSED for syntax

# Verify scripts
bash -n scripts/build.sh
bash -n scripts/run-qemu.sh

# Git status
git status --short
git log --oneline -5
```

### Expected ARM64 Test Output

```
=====================================
AgentOS Boot Tests
=====================================

TEST: Architecture Check
STATUS: BLOCKED
DETAILS: Architecture: aarch64 (requires x86_64 Linux)

TEST: Build Script Check
STATUS: PASSED
DETAILS: Script syntax valid

TEST: Tool Check
STATUS: FAILED
DETAILS: Missing tools: qemu-system-x86_64 qemu-img

TEST: Image Check
STATUS: BLOCKED
DETAILS: No image found - run build.sh first (requires x86_64)

=====================================
Test Results Summary
=====================================
      2 STATUS: BLOCKED
      1 STATUS: FAILED
      1 STATUS: PASSED
```

## x86-64 Linux Build Instructions

### Transfer Repository

```bash
# Clone or copy the repository
git clone <repo-url> agentos
cd agentos
```

### System Requirements

|| Requirement | Minimum | Recommended |
||------------|---------|-------------|
|| Architecture | x86-64 (amd64) | x86-64 |
|| OS | Debian 12, Ubuntu 22.04+ | Debian 12, Ubuntu 24.04 |
|| CPU | 2 cores | 4+ cores |
|| Memory | 4GB | 8GB+ |
|| Disk Space | 20GB free | 50GB+ |
|| Virtualization | None (for build) | KVM for testing |

### Install Build Dependencies

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

### Build Process

```bash
# 1. Make scripts executable
chmod +x scripts/build.sh scripts/run-qemu.sh test/boot-test.sh

# 2. Verify architecture
uname -m  # Must show: x86_64

# 3. Run the build
./scripts/build.sh
```

### Automated Test

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
STATUS: PASSED
DETAILS: Image exists and is valid
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

## Continuous Integration

This project includes GitHub Actions workflow at `.github/workflows/build-test.yml`:

```yaml
# Trigger conditions
on: push, pull_request, workflow_dispatch

# Jobs
build:    # Runs on ubuntu-latest, installs dependencies, builds, validates artifacts
boot-test: # Downloads artifacts, runs QEMU boot test with timeout
```

To use CI:
1. Push to `main` or `master` branch
2. Open a pull request
3. Watch Actions tab for build results

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