# AgentOS Hardware Compatibility

## Supported Architectures
- x86-64 (AMD64/Intel 64) - Primary architecture

## CPU Support
- Modern x86-64 processors (2015+)
- Intel: Core i3/i5/i7/i9, Xeon
- AMD: Ryzen, EPYC, Athlon

## Graphics Support

### Integrated Graphics
- Intel HD/UHD Graphics (Gen 8+)
- AMD Radeon Vega (Zen architecture)

### Discrete Graphics
- NVIDIA: GeForce GTX 10xx+ ( nouveau driver )
- AMD: Radeon RX 500+ series (amdgpu driver)

### Display Servers
- Wayland (primary)
- X11 (fallback)

## Storage Controllers

### SATA
- AHCI mode: Full support

### NVMe
- PCIe 3.0/4.0: Native support

### USB Storage
- USB 3.0+: Full support

### Network Storage
- NFS, SMB/CIFS: Supported via network tools

## Networking

### Ethernet
- Intel: e1000, i210/i211, X710 (ixgbe)
- Realtek: r8169
- AMD: PCNet III (emulated), Mellanox ConnectX

### Wireless
- Intel: iwlwifi (Intel Wireless 7260+)
- Atheros: ath10k (Qualcomm Atheros)
- Broadcom: brcmfmac (BCM43xx)

### Wired
- All standard 10/100/1000/2.5GbE controllers

## Audio

### Audio Chipset Support
- Intel HD Audio: Native support
- AMD Audio: Native support
- Realtek: Native support via ALSA
- Creative Sound Blaster: snd-oxygen module

## USB

### USB Controllers
- Intel xHCI (USB 3.0+)
- AMD Promontory

### Device Classes
- HID (keyboard, mouse): Native
- Mass Storage: Native
- HID Webcams: Native
- Serial Converters: FTDI, CP210x, CH34x

## Power Management

### ACPI Support
- S3/S4 (Sleep/Hibernation): Supported with caveats
- Battery management: Supported on laptops
- CPU frequency scaling: intel_pstate, amd_pstate

### Known Limitations
- Hibernation may require swap configuration
- USB wake from sleep may need tuning

## Virtualization

### Hypervisor Support
- KVM/QEMU: Primary virtualization platform
- VMware: TSC scaling issues possible
- VirtualBox: Functional but slower performance

## Hardware Tested

### Virtual Hardware (QEMU/KVM)
- Standard x86_64 virtual machine
- VirtIO block devices
- VirtIO network
- QXL graphics (for display testing)

### Physical Hardware (Verification Required)
List specific models that have been tested with results.

## Hardware Detection

AgentOS usesudev for hardware detection and configuration.  
Log files at `/var/log/udev.log` for debugging detection issues.

## Adding Hardware Support

To add support for new hardware:
1. Identify the device with `lspci` or `lsusb`
2. Check if kernel driver exists (`modinfo <driver>`)
3. Add driver to initramfs if needed
4. Configure relevant services
5. Document in this file with test results