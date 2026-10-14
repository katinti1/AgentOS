# AgentOS Testing Guide

## Test Categories

### 1. Build Tests
- Image creation completes successfully
- File system integrity checks pass
- Bootloader installation verification

### 2. Boot Tests
- Kernel loads and initializes
- Root filesystem mounts correctly
- Systemd boot sequence completes
- Essential services start

### 3. System Tests
- User login functionality
- Package management works
- Networking is functional
- Hardware detection

### 4. Hermes Agent Tests
- Agent service starts correctly
- Basic conversational functionality
- Tool access permissions
- Desktop integration

## Running Tests

### Build Verification

```bash
# Verify image was created
ls -la build/agentos.qcow2

# Check image size
qemu-img info build/agentos.qcow2

# Verify filesystem (if loop-mounted)
sudo e2fsck -f rootfs
```

### QEMU Boot Test

```bash
# Automated boot test
./test/boot-test.sh

# Manual test
./scripts/run-qemu.sh --snapshot
```

### Boot Test Script

The `test/boot-test.sh` script performs automated testing:

1. **Image Inspection**
   - Verify image exists and is valid
   - Check partition table

2. **QEMU Boot Sequence**
   - Start QEMU with serial console output
   - Monitor boot progress
   - Detect kernel messages

3. **Service Verification**
   - Check systemd boot completion
   - Verify SSH is listening
   - Check Hermes agent status

4. **Console Output Analysis**
   - Look for boot errors
   - Identify success markers

## Test Results Format

All tests produce output in the following format:

```
TEST: <test-name>
STATUS: PASSED|FAILED|BLOCKED
DETAILS: <brief description>
TIMESTAMP: <ISO-8601 timestamp>
```

## Continuous Integration

CI runs on x86-64 Linux runners:

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-system-x86 qemu-utils debootstrap
      - name: Build image
        run: ./scripts/build.sh
      - name: Run boot test
        run: ./test/boot-test.sh
```

## Known Limitations

### On ARM/Android (Current Environment)
- Cannot build x86-64 images
- Cannot run QEMU boot tests
- Build scripts will report `BLOCKED`

### Resolution
Tests must be run on an x86-64 Linux host. The current development environment (Termux on Android) is being used for:
- Documentation development
- Build script creation
- Configuration management
- Git history management

Actual verification requires x86-64 hardware.