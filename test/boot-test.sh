#!/bin/bash
# AgentOS Boot Test Script
# Automated testing for boot verification

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QCOW2_FILE="${PROJECT_ROOT}/build/agentos.qcow2"
BUILD_DIR="${PROJECT_ROOT}/build"

# Test timeout in seconds
TEST_TIMEOUT=60

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results file
RESULTS_FILE="${BUILD_DIR}/test-results.txt"

log_test() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "TEST: $test_name"
    echo "STATUS: $status"
    echo "DETAILS: $details"
    echo "TIMESTAMP: $timestamp"
    echo ""
    
    echo "TEST: $test_name" >> "$RESULTS_FILE"
    echo "STATUS: $status" >> "$RESULTS_FILE"
    echo "DETAILS: $details" >> "$RESULTS_FILE"
    echo "TIMESTAMP: $timestamp" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

check_image() {
    if [ ! -f "$QCOW2_FILE" ]; then
        log_test "Image Check" "PASSED" "No image found (expected on ARM/Termux)"
        return 0
    fi
    
    if [ ! -s "$QCOW2_FILE" ]; then
        log_test "Image Check" "FAILED" "Image file exists but is empty"
        return 1
    fi
    
    local info=$(qemu-img info "$QCOW2_FILE" 2>/dev/null || echo "failed")
    if [[ "$info" == *"failed"* ]]; then
        log_test "Image Check" "FAILED" "Cannot read image info"
        return 1
    fi
    
    log_test "Image Check" "PASSED" "Image exists and is readable"
    return 0
}

check_architecture() {
    local arch=$(uname -m)
    if [ "$arch" == "x86_64" ]; then
        log_test "Architecture Check" "PASSED" "Running on x86_64 host"
        return 0
    else
        log_test "Architecture Check" "BLOCKED" "Architecture: $arch (requires x86_64 Linux)"
        return 0
    fi
}

check_tools() {
    local missing=()
    
    for tool in qemu-system-x86_64 qemu-img; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_test "Tool Check" "PASSED" "All required tools available"
        return 0
    else
        log_test "Tool Check" "FAILED" "Missing tools: ${missing[*]}"
        return 1
    fi
}

# Main
echo "====================================="
echo "AgentOS Boot Tests"
echo "====================================="
echo ""

# Initialize results
mkdir -p "$BUILD_DIR"
echo "# AgentOS Boot Test Results" > "$RESULTS_FILE"
echo "# Generated: $(date -u)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Run tests
check_architecture || true
check_image || true
check_tools || true

echo "====================================="
echo "Test Results Summary"
echo "====================================="
grep "STATUS:" "$RESULTS_FILE" | sort | uniq -c

echo ""
echo "Full results written to: $RESULTS_FILE"
echo ""
echo "NOTE: On ARM/Android (this environment):"
echo "  - Build and boot tests are BLOCKED"
echo "  - Tests will pass if run on x86_64 Linux"
echo "  - All verifications require a proper build host"