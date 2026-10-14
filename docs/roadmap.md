# AgentOS Roadmap

## Vision

Create a Linux-based PC operating system where intelligent agents are a first-class citizen, seamlessly integrated into the computing experience.

## Goals

### Phase 1: Foundation (Q4 2024 - Q1 2025)
- ✅ Establish repository structure with documentation
- ✅ Define system architecture
- ⏳ Create build system for x86-64 Linux hosts
- ⏳ Implement minimal bootable system with QEMU tests

### Phase 2: Core System (Q2 2025)
- ⏳ Linux kernel with common drivers
- ⏳ systemd as init system
- ⏳ Basic desktop environment (GNOME or XFCE)
- ⏳ Package management (apt)
- ⏳ User and group management
- ⏳ Networking foundation
- ⏳ Logging and diagnostics

### Phase 3: Hermes Agent Integration (Q3 2025)
- ⏳ Hermes runtime environment
- ⏳ System service for agent
- ⏳ Desktop integration (D-Bus interface)
- ⏳ Tool access with permissions
- ⏳ AI provider configuration support

### Phase 4: Desktop Experience (Q4 2025)
- ⏳ Full desktop environment
- ⏳ File manager with agent integration
- ⏳ Terminal with agent commands
- ⏳ Notifications system
- ⏳ Accessibility features

### Phase 5: Application Platform (Q1 2026)
- ⏳ Application packaging system
- ⏳ Software store/discovery
- ⏳ Sandbox policies
- ⏳ Development SDK

### Phase 6: Installation & Updates (Q2 2026)
- ⏳ Bootable ISO for installation
- ⏳ Physical PC installer
- ⏳ Update verification
- ⏳ Recovery system

### Phase 7: Production Ready (Q3 2026)
- ⏳ Security hardening
- ⏳ Performance optimization
- ⏳ Documentation complete
- ⏳ Community adoption

## Milestone Definitions

### M1: Bootable System
A Linux kernel boots in QEMU, mounts a root filesystem, and runs init (PID 1).

### M2: Desktop Environment
Graphical display works, user can log in, basic applications launch and close.

### M3: Hermes Service
The Hermes agent runs as a systemd service, starts at boot, and serves API requests.

### M4: End-to-End
User can install AgentOS from ISO, log into desktop, and interact with Hermes through the UI.

## Current Status

**Development Environment:** Android/Termux (aarch64) - source development only  
**Build Requirements:** x86-64 Linux with QEMU for testing  
**Current Work:** Repository infrastructure and documentation

## How to Contribute

1. Fork the repository
2. Set up a proper x86-64 build environment
3. Run existing tests to verify baseline
4. Work on your assigned feature branch
5. Submit a pull request with tests

## Notes

- This project cannot be built or tested on ARM/Android hardware
- Development continues in the source repository
- Testing requires x86-64 Linux with virtualization support