# AgentOS Build Guide

## Prerequisites

### Host Requirements
- **Architecture:** x86-64 (amd64)
- **OS:** Debian 12, Ubuntu 22.04+, or compatible
- **Privileges:** Root/sudo access required
- **Disk Space:** Minimum 20GB free space

### Required Packages

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
    wget
```

### Optional Packages

```bash
# For building with specific kernel versions
sudo apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev
```

## Quick Build

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/agentos.git
cd agentos
```

### 2. Make the Build Script Executable

```bash
chmod +x scripts/build.sh
```

### 3. Build the Image

```bash
./scripts/build.sh
```

This will produce:
- `build/agentos.iso` - Installation image
- `build/agentos.qcow2` - Virtual machine image

## Detailed Build Process

### Step 1: Create Build Directories

```bash
mkdir -p build kernel rootfs packages
```

### Step 2: Bootstrap Root Filesystem

```bash
# Create root filesystem using debootstrap
sudo debootstrap --arch amd64 bookworm rootfs http://deb.debian.org/debian/
```

### Step 3: Configure the System

```bash
# Chroot into the filesystem and configure
sudo chroot rootfs /bin/bash << 'EOF'
# Set up networking
echo "agentos" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
192.168.1.10    agentos
HOSTS

# Install essential packages
apt update
apt install -y systemd-sysv grub-efi-amd64 qemu-guest-agent \
    linux-image-amd64 sudo openssh-server

# Create user
useradd -m -s /bin/bash agent

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Enable SSH
systemctl enable ssh

# Cleanup
apt clean
rm -rf /var/lib/apt/lists/*
EOF
```

### Step 4: Install GRUB

```bash
# Install GRUB for UEFI boot
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=rootfs/boot/efi \
    --boot-directory=rootfs/boot \
    --removable \
    rootfs

# Generate GRUB config
sudo chroot rootfs /bin/bash << 'EOF'
grub-mkconfig -o /boot/grub/grub.cfg
EOF
```

### Step 5: Create the Image

```bash
# Create QCOW2 image
qemu-img create -f qcow2 build/agentos.qcow2 10G

# Install filesystem to image
sudo mkdir -p /mnt
sudo mount -o loop rootfs/boot/efi/EFI/BOOT/BOOTX64.EFI /mnt 2>/dev/null || true
sudo chroot rootfs qemu-img convert -f qcow2 -O qcow2 build/agentos.qcow2

# Alternative: Use debootstrap directly to QCOW2
# This requires more advanced setup with libvirt or direct kernel boot
```

## Testing

### Run in QEMU

```bash
./scripts/run.sh
```

Or manually:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -smp 2 \
    -drive if=none,file=build/agentos.qcow2,id=drive0 \
    -device virtio-blk-pci,drive=drive0 \
    -display gtk
```

Without KVM (slower):

```bash
qemu-system-x86_64 \
    -m 2048 \
    -smp 2 \
    -drive if=none,file=build/agentos.qcow2,id=drive0 \
    -device virtio-blk-pci,drive=drive0 \
    -display gtk
```

### Expected Boot Sequence

1. GRUB bootloader loads
2. Linux kernel boots
3. systemd initializes
4. Basic services start
5. Login prompt appears (or display manager for desktop)

## Troubleshooting

### Boot Issues

1. **Kernel panic:** Check kernel configuration
2. **GRUB errors:** Verify EFI boot partition
3. **Root filesystem not found:** Check /etc/fstab

### Common Errors

```bash
# debootstrap fails
sudo debootstrap --foreign --arch amd64 bookworm rootfs

# GRUB installation fails
sudo grub-install --target=x86_64-pc --boot-directory=rootfs/boot rootfs
```

## Cross-Compilation Note

**This project cannot be built on ARM/Android (including Termux).**  
You must use an x86-64 Linux system with QEMU for building and testing.