# AgentOS

AgentOS is a Linux-based PC operating system with intelligent agent integration.

## Repository Structure

```
agentos/
├── docs/              # Documentation
│   ├── architecture.md
│   ├── build-guide.md
│   ├── hardware-support.md
│   ├── roadmap.md
│   ├── security.md
│   └── testing.md
├── scripts/           # Build and utility scripts
│   ├── build.sh
│   └── run-qemu.sh
├── test/              # Test scripts
│   └── boot-test.sh
├── build/             # Build outputs (gitignored)
├── rootfs/            # Root filesystem (gitignored)
├── kernel/            # Kernel sources and configs
├── boot/              # Bootloader configs
├── system/            # System service definitions
├── desktop/           # Desktop environment configs
├── hermes/            # Hermes agent integration
├── installer/         # Installation scripts
├── patches/           # Source patches
├── configs/           # System-wide configurations
├── README.md
├── LICENSE
└── .gitignore
```

## Quick Links

- [Architecture](docs/architecture.md)
- [Build Guide](docs/build-guide.md)
- [Testing](docs/testing.md)
- [Roadmap](docs/roadmap.md)

## Build Requirements

See [Build Guide](docs/build-guide.md) for detailed requirements.

**WARNING:** This project cannot be built on ARM/Android (including Termux). You need an x86-64 Linux system with QEMU.