# AgentOS Architecture

## Overview

AgentOS is a Linux-based PC operating system designed with the integration of artificial intelligence at its core. The architecture follows the principle that "intelligence should be a platform, not an application."

## System Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     User Applications                        │
│  (Desktop Environment, Terminal, File Manager, etc.)        │
├─────────────────────────────────────────────────────────────┤
│                 Hermes Agent Integration                   │
│  (System service, desktop integration, tool access)          │
├─────────────────────────────────────────────────────────────┤
│                    Desktop Environment                     │
│  (GNOME/Wayland, Display Manager, Session Manager)           │
├─────────────────────────────────────────────────────────────┤
│                      System Services                         │
│  (systemd, networking, logging, device management)         │
├─────────────────────────────────────────────────────────────┤
│                       Linux Kernel                         │
│  (Linux 6.x, x86-64 architecture)                            │
├─────────────────────────────────────────────────────────────┤
│                      Bootloader                                │
│  (GRUB2 for BIOS/UEFI)                                     │
├─────────────────────────────────────────────────────────────┤
│                    Storage (Root Filesystem)                 │
└─────────────────────────────────────────────────────────────┘
```

## Component Selection Rationale

### Linux Kernel
- Version: 6.x LTS series
- Configuration: Customized for modern desktop hardware
- Rationale: Well-maintained, broad hardware support, extensive documentation

### Init System: systemd
- Chosen for: Process supervision, service management, socket activation
- Alternative considered: OpenRC (less suitable for modern desktop integration)

### Package Management: apt (Debian)
- Rationale: Mature, stable, vast package ecosystem
- Base: Debian bullseye or bookworm for stability

### Desktop Environment
- Primary choice: GNOME 45 (Wayland)
  - Modern interface, good accessibility, strong community
- Alternative: XFCE (lighter, better for older hardware)

### Bootloader
- GRUB2 with UEFI and BIOS support
- Rationale: Industry standard, excellent documentation

### Image Format
- Primary: QCOW2 for development/testing
- Production: ISO9660 hybrid for installation

## Hermes Agent Integration

### Service Architecture
```
┌─────────────────────────────────────────────────┐
│  Hermes Agent Service (PID 1)                    │
│  - Manages agent lifecycle                      │
│  - Handles startup/shutdown                     │
│  - Provides IPC to desktop                      │
└─────────────────────────────────────────────────┘
```

### Integration Points
1. **System Service** - Runs as a supervised systemd service
2. **Desktop Integration** - D-Bus interfaces for UI communication
3. **Tool Access** - Controlled access to system resources
4. **Configuration** - Integrated into system settings

## Build System

### Build Environment Requirements
- x86-64 Linux host (cannot build on ARM/Android)
- QEMU 7.0+ for emulation testing
- debootstrap for root filesystem creation
- GRUB for bootloader

### Build Artifacts
- `agentos.iso` - Installation medium
- `agentos.qcow2` - Virtual machine disk image
- `kernel/` - Kernel source and configuration
- `rootfs/` - Root filesystem tarball

## Security Model

### Default Configuration
- Unprivileged user accounts for daily use
- sudo for administrative access
- SELinux/AppArmor for additional hardening (optional)
- Secure boot support via systemd-boot

### Hermes Agent Security
- Least privilege principle
- User confirmation for sensitive operations
- Audit logging for all actions
- Network access control

## File System Layout

```
/
├── bin/           Essential user binaries
├── boot/          Boot files (kernel, initramfs, bootloader)
├── dev/           Device files
├── etc/           System configuration
├── home/          User home directories
├── lib/           Shared libraries
├── media/         Mount points for removable media
├── mnt/           Temporary mount points
├── opt/           Optional software
├── proc/          Process information
├── root/          Root user home
├── run/           Runtime data
├── sbin/          System binaries
├── srv/           Service data
├── sys/           Sysfs mount
├── tmp/           Temporary files
├── usr/           User utilities
│   ├── bin/
│   ├── lib/
│   └── share/
├── var/           Variable data
│   ├── cache/
│   ├── log/
│   ├── lib/
│   ├── local/
│   └── spool/
└── agentos/       AgentOS-specific directories
    ├── config/    System-wide configuration
    ├── data/      Persistent application data
    └── var/       Log and runtime files
```